# Configure Apache Server as you normally would:


class { 'apache':
  default_mods => false,
}

class { 'apache_hardening':
  provider => 'puppetlabs/apache'
}
