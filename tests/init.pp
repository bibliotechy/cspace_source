# The baseline for module testing used by Puppet Labs is that each manifest
# should have a corresponding test manifest that declares that class or defined
# type.
#
# Tests are then run by using puppet apply --noop (to check for compilation
# errors and view a log of events) or by fully applying the test in a virtual
# environment (to compare the resulting system state to the desired state).
#
# Learn more about module testing here:
# http://docs.puppetlabs.com/guides/tests_smoke.html
#

# Create an instance of this class

# FIXME: the values below should more flexibly be read in from a
# per-node Environment, from configuration files, or from Heira,
# rather than being hard-coded.
#
# See, for instance:
# http://puppetlabs.com/blog/the-problem-with-separating-data-from-puppet-code
# and specifically:
# http://docs.puppetlabs.com/guides/environment.html
# http://docs.puppetlabs.com/hiera/1/

include cspace_environment::env
include cspace_user

class { 'cspace_source': }

notice( "CollectionSpace source code directory is ${cspace_source::cspace_source_dir}" )

