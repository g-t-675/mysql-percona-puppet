# == Class: percona::xtradb_cluster
#
# Installation and basic configuration of an xtradb cluster node.
#
# === Parameters
#
# [*cluster*]
#   This is a hash with all required information for all nodes in the cluster.
#
# === Variables
# 
# N/A
#
# === Examples
#
# percona::xtradb_cluster { 'dbcluster01':
#     cluster => {
#        # cluster wide variables
#        name            => 'dbcluster01',
#        sst_method      => 'rsync', # options are rsync, mysqldump, xtrabackup, ...
#        sst_auth        => 'someuser:somepassword', # if left temp
#        mysql_root_user => 'root', # mysql root user must be the same acros the cluster
#        mysql_root_pwd  => 'secret', # mysql root pwd must be the same acros the cluster
#        maintenance_pwd => 'also_secret', # for debian-sys-maint, must be the same acros the cluster
#        reform          => true, # opportunistically reform the cluster after a complete clusterwide failure,
#        # nodes
#        nodes           => {
#            'foo.example.com' => {
#                name         => 'node1', 
#                gcomm_addr   => 'foo', # some_ip_or_hostname, should probably be 0.0.0.0 or internal vlan ip
#                gcomm_port   => 4567, # 4567
#                mysql_addres => '0.0.0.0', # some_ip_or_hostname, should probably be 0.0.0.0 or internal vlan ip
#                mysql_port   => 3306, # portnumber, should be default 3306
#            },
#            'bar.example.com' => {
#                name         => 'node2', 
#                gcomm_addr   => 'bar', # some_ip_or_hostname, should probably be 0.0.0.0 or internal vlan ip
#                gcomm_port   => 4567, # 4567
#                mysql_addres => '0.0.0.0', # some_ip_or_hostname, should probably be 0.0.0.0 or internal vlan ip
#                mysql_port   => 3306, # portnumber, should be default 3306
#            },
#            'baz.example.com' => {
#                name         => 'node3', 
#                gcomm_addr   => 'naz4', # some_ip_or_hostname, should probably be 0.0.0.0 or internal vlan ip
#                gcomm_port   => 4567, # 4567
#                mysql_addres => '0.0.0.0', # some_ip_or_hostname, should probably be 0.0.0.0 or internal vlan ip
#                mysql_port   => 3306, # portnumber, should be default 3306
#            },
#        },
#        # tuning applied for every node (unless specified in a node itself)
#        tuning          => {     
#            innodb_buffer_pool_size => '256M',
#        }    
#    }
#
# === Authors
#
# Proteon
#
# === Copyright
#
# Copyright 2013 Proteon
#
class percona::xtradb_cluster (
    $cluster = {}, # default value of {} to silence puppet-lint
    $bind_address = '0.0.0.0', # on which address the server wil listen
    $wsrep_node_address = $::percona::xtradb_cluster::cluster['nodes'][$::fqdn]['mysql_addres'], #'0.0.0.0', # The address to bind the replication (port 4567) connection on
    $package_name = 'percona-xtradb-cluster-server-5.5',
    # some overridable settings
    $wsrep_convert_lock_to_trx = 1, 
    $wsrep_replicate_myisam = 1,
    $wsrep_retry_autocommit = 1,
    $wsrep_certify_nonpk = 1,
    $wsrep_debug = 0,
    $default_character_set = 'utf8',
    $character_set_server = 'utf8mb4',
    $collation_server = 'utf8mb4_general_ci',
) {
    # to include the repository
    include percona

    $mysql_user         = $cluster['mysql_root_user']
    $mysql_password     = $cluster['mysql_root_pwd']
    $maintenance_pwd    = $cluster['maintenance_pwd']

    if $cluster['restart_on_changes'] == true {
        $change_notification = Service['mysql']
    } else {
        $change_notification = undef
    }

    $_bind_address = $bind_address # TODO: allow for overriding from a variable in $cluster
    $_wsrep_node_address = $wsrep_node_address # TODO: allow for overriding from a variable in $cluster

    package { $package_name:
        alias    => 'mysql-server',
        require  => Apt::Source['percona'],
    }

    ##### Config #####

    # main configuration, should be quite neutral

    case $lsbdistcodename {
        'wily', 'xenial': { $my_cnf_file = '/etc/mysql/percona-xtradb-cluster.cnf' }
        default: 	  { $my_cnf_file = '/etc/mysql/my.cnf' }
    }

    file { $my_cnf_file:
        ensure  => present,
        owner   => 'root',
        group   => 'mysql',
        mode    => '0640',
        content => template('percona/my.cnf.erb'),
        require => Package[$percona::xtradb_cluster::package_name],
    }

    file { '/etc/mysql/conf.d/logging.cnf':
        ensure  => present,
        owner   => 'mysql',
        group   => 'mysql',
        mode    => '0600',
        content => template('percona/logging.cnf.erb'),
        require => Package[$percona::xtradb_cluster::package_name],
        notify  => $change_notification,
    }

    # general Percona (galera) configuration
    file { '/etc/mysql/conf.d/percona_general.cnf':
        ensure  => present,
        owner   => 'mysql',
        group   => 'mysql',
        mode    => '0600',
        content => template('percona/percona_general.cnf.erb'),
        require => Package[$package_name],
        notify  => $change_notification,
    }

    ##### Some initialization #####
    file { '/root/.my.cnf':
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => Exec['Initialize MySQL server root password'],
    }

    exec { 'Initialize MySQL server root password':
        unless  => '/usr/bin/test -f /root/.my.cnf',
        command => "/usr/bin/mysqladmin -u${mysql_user} password '${mysql_password}'",
        notify  => Exec['Generate my.cnf'],
        require => Package['mysql-server'],
    }

    exec { 'Generate my.cnf':
        command     => "/bin/echo -e '[mysql]\\nuser=${mysql_user}\\npassword=${mysql_password}\\n[mysqladmin]\\nuser=${mysql_user}\\npassword=${mysql_password}\\n[mysqldump]\\nuser=${mysql_user}\\npassword=${mysql_password}\\n[mysqlshow]\\nuser=${mysql_user}\\npassword=${mysql_password}\\n' > /root/.my.cnf",
        unless      => '/usr/bin/test -f /root/.my.cnf',
        refreshonly => true,
        creates     => '/root/.my.cnf',
    }

    file { '/etc/mysql/debian.cnf':
        ensure  => present,
        owner   => 'root',
        group   => 'mysql',
        mode    => '0640',
        content => template('percona/debian.cnf.erb'),
        require => [
            Package[$percona::xtradb_cluster::package_name],
            Service['mysql'], # I want this to change after a refresh
        ],
    }

    percona::rights { 'debian-sys-maint user':
        database        => '*',
        user            => 'debian-sys-maint',
        password        => $maintenance_pwd,
        priv            => 'SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, SUPER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER',
        grant_option    => true,
        require         => [
            Service['mysql'],
            Exec['Generate my.cnf']
        ],
    }

    service { 'mysql':
        ensure  => 'running',
        enable  => $::mysql_run_at_boot,
        require => Package['mysql-server']
    }

    file { '/etc/logrotate.d/percona-xtradb-cluster-server-5.5':
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        source  => 'puppet:///modules/percona/percona-xtradb-cluster-server-5.5.logrotate',
        require => Package[$percona::xtradb_cluster::package_name],
    }
}
