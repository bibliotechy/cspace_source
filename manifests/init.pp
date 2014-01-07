# == Class: cspace_source
#
# Full description of class cspace_source here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { cspace_source:
#  servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2013 Your name here, unless otherwise noted.
#

# May require installation of the puppetlabs/vcsrepo module; e.g.
# sudo puppet module install puppetlabs-vcsrepo

# Test standlone with a reference to the modulepath in which that module is installed; e.g.
# puppet apply --modulepath=/etc/puppet/modules ./tests/init.pp

include cspace_environment::tempdir
include cspace_environment::user
include stdlib # for 'validate_array()'

class cspace_source( $env_vars, $exec_paths = [ '/bin', '/usr/bin' ], $source_dir_path = undef, $user_acct = $cspace_environment::user::user_acct_name ) {
  
  validate_array($env_vars)
  
  # ---------------------------------------------------------
  # Verify presence of required executables
  # ---------------------------------------------------------
  
  # FIXME: Replace or augment with cross-platform compatible
  # methods for finding executables, including on Windows.
    
  notify{ 'Checking for build tools':
    message => 'Checking for availability of Ant and Maven build tools ...',
    tag     => [ 'services', 'application', 'ui' ],
    before  => [
        Exec [ 'Find Ant executable' ],
        Exec [ 'Find Maven executable' ],
    ],
  }
  
  exec { 'Find Ant executable':
    command   => '/bin/sh -c "command -v ant"',
    path      => $exec_paths,
    logoutput => true,
    tag       => [ 'services', 'application', 'ui' ],
    before => Notify[ 'Creating source directory' ],
  }
  
  exec { 'Find Maven executable':
    command   => '/bin/sh -c "command -v mvn"',
    path      => $exec_paths,
    logoutput => true,
    tag       => [ 'services', 'application', 'ui' ],
    before => Notify[ 'Creating source directory' ],
  }
  
  # Note: The 'vcsrepo' resource, starting with version 0.2.0 of 2013-11-13,
  # will intrinsically verify that a Git client exists ("Add autorequire for
  # Package['git']"), so we don't need to independently verify its presence.
  
  # ---------------------------------------------------------
  # Ensure presence of a directory to contain source code
  # ---------------------------------------------------------
  
  # Use the provided source code directory, if available.
  if $source_dir_path != undef {
    $cspace_source_dir = $source_dir_path
    # FIXME: Verify the existence of, and (optionally) the requisite
    # access privileges to, the provided source code directory.
  }
  # Otherwise, use a directory in a system temporary location.
  # FIXME: We might consider changing this location to the home directory
  # of the CollectionSpace admin user.
  else {
    include cspace_environment
    $system_temp_dir = $cspace_environment::tempdir::system_temp_directory
    $default_cspace_source_dir_name = 'cspace-source'
    $default_cspace_source_dir = "${system_temp_dir}/${default_cspace_source_dir_name}"
    $cspace_source_dir = $default_cspace_source_dir
  }

  notify{ 'Creating source directory':
    message => 'Creating directory to hold CollectionSpace source code, if not present ...',
    tag     => [ 'services', 'application', 'ui' ],
    before  => File [ 'Ensure CollectionSpace source directory' ],
  }
  
  file { 'Ensure CollectionSpace source directory':
    ensure  => 'directory',
    path    => $cspace_source_dir,
    user    => $user_acct,
    tag     => [ 'services', 'application', 'ui' ],
  }
  
  # ---------------------------------------------------------
  # Download CollectionSpace source code
  # ---------------------------------------------------------
  
  # Download the Application layer source code
  
  # The Services layer build is dependent on the Application
  # layer build, so Application layer source code is downloaded
  # even when this manifest is invoked with the 'services' tag. 
    
  notify{ 'Downloading Application layer':
    message => 'Downloading Application layer source code ...',
    tag     => [ 'services', 'application' ],
    before  => Vcsrepo [ 'Download Application layer source code' ],
    require => File [ 'Ensure CollectionSpace source directory' ],
  }
  
  vcsrepo { 'Download Application layer source code':
    ensure   => latest,
    provider => 'git',
    source   => 'https://github.com/collectionspace/application.git',
    revision => 'master',
    path     => "${cspace_source_dir}/application",
    user     => $user_acct,
    tag      => [ 'services', 'application' ],
    require  => File[ 'Ensure CollectionSpace source directory' ],
  }

  # Download the Services layer source code
  
  notify{ 'Downloading Services layer':
    message => 'Downloading Services layer source code ...',
    tag     => 'services',
    before  => Vcsrepo [ 'Download Services layer source code' ],
    require  => File [ 'Ensure CollectionSpace source directory' ],
  }
  
  vcsrepo { 'Download Services layer source code':
    ensure   => latest,
    provider => 'git',
    source   => 'https://github.com/collectionspace/services.git',
    revision => 'master',
    path     => "${cspace_source_dir}/services",
    user     => $user_acct,
    tag      => 'services',
    require  => File [ 'Ensure CollectionSpace source directory' ],
  }
  
  # Download the UI layer source code

  notify{ 'Downloading UI layer':
    message => 'Downloading UI layer source code ...',
    tag     => 'ui',
    before  => Vcsrepo [ 'Download UI layer source code' ],
    require => File [ 'Ensure CollectionSpace source directory' ],
  }
  
  vcsrepo { 'Download UI layer source code':
    ensure   => latest,
    provider => 'git',
    source   => 'https://github.com/collectionspace/ui.git',
    revision => 'master',
    path     => "${cspace_source_dir}/ui",
    user     => $user_acct,
    tag      => 'ui',
    require  => File[ 'Ensure CollectionSpace source directory' ],
  }
  
  # ---------------------------------------------------------
  # Build and deploy CollectionSpace's layers
  # ---------------------------------------------------------
  
  $mvn_clean_cmd = 'mvn clean'
  $mvn_clean_install_cmd = "${mvn_clean_cmd} install -DskipTests"
  
  # Build and deploy the Application layer

  # The Services layer build is dependent on the Application
  # layer build, so the Application layer build is performed
  # even when this manifest is invoked with the 'services' tag. 
    
  notify{ 'Building Application layer':
    message => 'Building and deploying Application layer ...',
    tag     => [ 'services', 'application' ],
    before  => Exec [ 'Build and deploy of Application layer source' ],
    require => Vcsrepo[ 'Download Application layer source code' ],
  }
  
  exec { 'Build and deploy of Application layer source':
    command     => $mvn_clean_install_cmd,
    cwd         => "${cspace_source_dir}/application",
    path        => $exec_paths,
    environment => $env_vars,
    user        => $user_acct,
    tag         => [ 'services', 'application' ],
    require     => [
      Vcsrepo[ 'Download Application layer source code' ],
      Exec[ 'Find Maven executable' ],
    ],
  }

  # Build and deploy the Services layer
  
  notify{ 'Building Services layer':
    message => 'Building Services layer ...',
    tag     => 'services',
    before  => Exec [ 'Build of Services layer source' ],
    require => Vcsrepo[ 'Download Services layer source code' ],
  }
  
  exec { 'Build of Services layer source':
    # Command below is a temporary placeholder during development
    # for the full build (very time consuming)
    command     => $mvn_clean_cmd,
    cwd         => "${cspace_source_dir}/services",
    path        => $exec_paths,
    environment => $env_vars,
    user        => $user_acct,
    tag         => 'services',
    require     => [
      Vcsrepo[ 'Download Services layer source code' ],
      Exec[ 'Find Maven executable' ],
    ],
  }
  
  notify{ 'Deploying Services layer':
    message => 'Deploying Services layer ...',
    tag     => 'services',
    before  => Exec [ 'Deploy of Services layer source' ],
  }
  
  exec { 'Deploy of Services layer source':
    # Command below is a temporary placeholder during development
    # for the full deploy (very time consuming)
    command     => 'ant deploy_services_artifacts',
    cwd         => "${cspace_source_dir}/services/services/JaxRsServiceProvider",
    path        => $exec_paths,
    environment => $env_vars,
    user        => $user_acct,
    tag         => 'services',
    require     => [
      Exec[ 'Build and deploy of Application layer source' ],
      Exec[ 'Build of Services layer source' ],
      Exec[ 'Find Ant executable' ],
    ],
  }
  
  # There is currently no UI layer build required: the tarball of the
  # CollectionSpace Tomcat server folder contains a prebuilt UI layer.

}

