#
# this script is responsible for performing initial setup
# configurations that are only necessary for our virtual
# box based installations.
#


# setup up puppetlabs repos and install Puppet 3.2
#
# it makes my life easier if I can assume Puppet 3.2
# b/c then the other manifests can utilize hiera!
# this is not required for bare-metal b/c we can assume
# that Puppet will be installed on the bare-metal nodes
# with the correct version
include puppet::repo::puppetlabs

case $::osfamily {
  'Redhat': {
    $puppet_pkg     = 'puppet'
    $puppet_version = '3.2.3-1.el6'
    $pkg_list       = ['git', 'curl', 'httpd']
  } 
  'Debian': {
    $puppet_pkg     = 'puppet-common'
    $puppet_version = '3.2.3-1puppetlabs1'
    $pkg_list       = ['git', 'curl', 'vim', 'cobbler']
    package { $puppet_pkg:
      ensure => $puppet_version,
    }
  }
}


package { 'puppet':
  ensure  => $puppet_version,
  require => Package[$puppet_pkg],
}

# dns resolution should be setup correctly
host {
  'build-server': ip => '192.168.242.100', host_aliases => 'build-server.domain.name';
}

# set up our hiera-store!
file { "${settings::confdir}/hiera.yaml":
  content =>
'
---
:backends:
  - data_mapper
:hierarchy:
  - "%{hostname}"
  - "rpc_type/%{rpc_type}"
  - "db_type/%{db_type}"
  - "tenant_network_type/%{tenant_network_type}"
  - "network_type/%{network_type}"
  - "network_plugin/%{network_plugin}"
  - "%{cinder_backend}"
  - "%{glance_backend}"
  - jenkins
  - "%{scenario}"
  - "%{openstack_role}"
  - "%{role}"
  - common
:yaml:
   :datadir: /etc/puppet/data/hiera_data
:data_mapper:
   # this should be contained in a module
   :datadir: /etc/puppet/data/data_mappings
'
}

# lay down a file that can be used for subsequent runs to puppet. Often, the
# only thing that you want to do after the initial provisioning of a box is
# to run puppet again. This command lays down a script that can be simply used for
# subsequent runs
file { '/root/run_puppet.sh':
  content =>
  "#!/bin/bash
  puppet apply --modulepath /etc/puppet/modules-0/ --certname ${clientcert} /etc/puppet/manifests/site.pp $*"
}

package { $pkg_list :
  ensure => present,
}
