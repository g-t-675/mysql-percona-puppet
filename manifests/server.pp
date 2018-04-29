# == Class: percona::server
#
# Installation and basic configuration of a percona server.
#
# === Parameters
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
# Copyright 2013-2015 Proteon
#
class percona::server (
    $package_name = 'percona-server-server',
    $root_password, # create a random password with something like 'pwgen 24 1
    $bind_address = '127.0.0.1', # on which address the server wil listen'
    $tuning = {},
    $restart_on_changes = true,
    $default_character_set = 'utf8',
    $character_set_server = 'utf8mb4',
    $collation_server = 'utf8mb4_general_ci',
) {
    # to include the repository
    include percona

    $mysql_user         = 'root'
    $mysql_password     = $root_password
    $_bind_address = $bind_address # because it's used with this name in the template

    if $restart_on_changes == true {
        $change_notification = Service['mysql']
    } else {
        $change_notification = undef
    }

    package { $package_name:
        alias    => 'mysql-server',
        require  => Apt::Source['percona'],
    }

    ##### Config #####

    case $lsbdistcodename {
        'wily', 'xenial': { $my_cnf_file = '/etc/mysql/percona-server.conf.d/mysqld.cnf' }
        default:          { $my_cnf_file = '/etc/mysql/my.cnf' }
    }

    # main configuration, should be quite neutral
    file { $my_cnf_file:
        ensure  => present,
        owner   => 'root',
        group   => 'mysql',
        mode    => '0640',
        content => template('percona/my.cnf.erb'),
        require => Package[$package_name],
    }

    file { '/etc/mysql/conf.d/logging.cnf':
        ensure  => present,
        owner   => 'mysql',
        group   => 'mysql',
        mode    => '0600',
        content => template('percona/logging.cnf.erb'),
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

    service { 'mysql':
        ensure  => 'running',
        enable  => $::mysql_run_at_boot,
        require => Package['mysql-server']
    }

    file { '/etc/logrotate.d/percona-server':
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        source  => 'puppet:///modules/percona/percona-xtradb-cluster-server-5.5.logrotate',
        require => Package[$package_name],
    }

    file { '/etc/mysql/conf.d/tuning.cnf':
        ensure  => present,
        owner   => 'root',
        group   => 'mysql',
        mode    => '0640',
        content => template('percona/tuning.cnf.erb'),
        require => Package[$package_name],
        notify  => $change_notification,
        before  => Service['mysql'],
    }

}
