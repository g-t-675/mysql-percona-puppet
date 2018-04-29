# == Define: percona::xtradb_cluster::node
#
# Configuration of a single node in a Percona Xtradb cluster
#
# === Parameters
#
# [*cluster*]
#   This is a hash with all required information for this node. See
#   xtradb_cluster.pp for more info.
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
define percona::xtradb_cluster::node (
    $cluster = {}, # big hashtable with all details
){

    $node = $::percona::xtradb_cluster::cluster['nodes'][$::fqdn]
    $tuning = $::percona::xtradb_cluster::cluster['tuning']

    if $cluster['restart_on_changes'] == true {
        $change_notification = Service['mysql']
    } else {
        $change_notification = undef
    }

    ##### Cluster specific config #####
    file { '/etc/mysql/conf.d/percona_cluster.cnf':
        ensure  => present,
        owner   => 'root',
        group   => 'mysql',
        mode    => '0640',
        content => template('percona/percona_cluster.cnf.erb'),
        require => Package[$percona::xtradb_cluster::package_name],
        notify  => $change_notification,
    }

    ##### Node specific config #####
    file { '/etc/mysql/conf.d/percona_node.cnf':
        ensure  => present,
        owner   => 'root',
        group   => 'mysql',
        mode    => '0640',
        content => template('percona/percona_node.cnf.erb'),
        require => Package[$percona::xtradb_cluster::package_name],
        notify  => $change_notification,
    }

    ##### Tuning config #####
    # Set and potentially override some tunin parameters
    file { '/etc/mysql/conf.d/tuning.cnf':
        ensure  => present,
        owner   => 'root',
        group   => 'mysql',
        mode    => '0640',
        content => template('percona/tuning.cnf.erb'),
        require => Package[$percona::xtradb_cluster::package_name],
        notify  => $change_notification,
        before  => Service['mysql'], # Due to initially setting
            # 'innodb_log_file_size' this file must be in place before the first
            # start.
    }
}
