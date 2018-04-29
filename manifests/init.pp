# == Class: percona
#
# Setup the apt repository for Percona. Installation of packages is done from
# other classes/defines.
#
# required modules: puppetlabs/puppet-apt
#
# === Parameters
#
# N/A
#
# === Variables
#
# N/A
#
# === Examples
#
# TBD
#
# === Authors
#
# Proteon
#
# === Copyright
#
# Copyright 2013 Proteon
#
class percona (
    $repo_location = 'http://repo.percona.com/apt',
) {
    include percona::secure_installation

    apt::source { 'percona':
        location   => $repo_location,
        release    => $::lsbdistcodename,
        repos      => 'main',
        key        => { 'server' => 'keyserver.ubuntu.com', 'id' => '4D1BB29D63D98E422B2113B19334A25F8507EFA5'},
    }
}
