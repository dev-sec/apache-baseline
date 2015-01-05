# Configure Apache Server as you normally would:


class { 'apache':
  default_mods  => false,
  default_vhost => false,
}

::apache::vhost { 'hardening-default':
  port            => 80,
  docroot         => $::apache::docroot,
  scriptalias     => $::apache::scriptalias,
  serveradmin     => $::apache::serveradmin,
  access_log_file => $::apache::access_log_file,
  priority        => '25',
  directories     => [
    { 'path'           => $::apache::docroot,
      'provider'       => 'files',
      'allow'          => 'from all',
      'order'          => 'allow,deny',
      'options'        => ['-Indexes','-FollowSymLinks','+MultiViews'],
      'allow_override' => ['None'],

    },
  ]
}

class { 'apache_hardening':
  provider => 'puppetlabs/apache'
}
