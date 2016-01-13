class nfs::client::debian (
  $nfs_v4 = false,
  $nfs_v4_idmap_domain = undef,
  $manage_rpcbind = true,
) {
  include nfs::client::debian::install
  include nfs::client::debian::configure
  include nfs::client::debian::service
}


class nfs::client::debian::install {
  if $manage_rpcbind {
    case $::lsbdistcodename {
      'lucid': {
        ensure_resource( 'package', 'portmap',    { 'ensure' => 'installed' } )
      }
      default: {
        ensure_resource( 'package', 'rpcbind',    { 'ensure' => 'installed' } )
      }
    }
  }
  ensure_resource( 'package', 'nfs-common',     { 'ensure' => 'installed' } )
  ensure_resource( 'package', 'nfs4-acl-tools', { 'ensure' => 'installed' } )
}


class nfs::client::debian::configure {
  Augeas {
    require => Class['nfs::client::debian::install']
  }

  if $nfs::client::debian::nfs_v4 {
    augeas { '/etc/default/nfs-common':
      context => '/files/etc/default/nfs-common',
      changes => ['set NEED_IDMAPD yes'],
    }
    augeas { '/etc/idmapd.conf':
      context => '/files/etc/idmapd.conf/General',
      lens    => 'Puppet.lns',
      incl    => '/etc/idmapd.conf',
      changes => ["set Domain $nfs::client::debian::nfs_v4_idmap_domain"],
    }
  }
}


class nfs::client::debian::service {
  Service {
    require => Class['nfs::client::debian::configure']
  }

  # On debian squeeze there isn't a separate idmapd, it lives inside of
  # nfs-common, but we can't do that. I may effectively be breaking v4
  # support, but I'd just prefer it all to work first.
  if $lsbdistcodename != ( 'squeeze' or 'wheezy' ) {
    if $nfs::client::debian::nfs_v4 {
      service { 'idmapd':
        ensure => running,
        subscribe => Augeas['/etc/idmapd.conf', '/etc/default/nfs-common'],
      }
      service { 'portmap':
        ensure    => running,
        enable    => true,
        hasstatus => false,
      }
    }
  }
}
