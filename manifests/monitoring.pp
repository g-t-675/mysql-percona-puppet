#
class percona::monitoring (
    $cluster_size_critical = '2',
    $cluster_size_warning = '2',
) {

    if $lsbdistcodename == 'xenial' {
        ensure_packages('nagios-plugins-contrib')
        $_script_path = '/usr/lib/nagios/plugins/pmp-check-mysql-status'
    } else {
        ensure_packages('percona-nagios-plugins')
        $_script_path = '/usr/lib64/nagios/plugins/pmp-check-mysql-status'
    }

    file { '/etc/nagios/nrpe.d/percona_cluster_checks.cfg':
        ensure     => 'present',
        owner      => 'root',
        group      => 'root',
        mode       => '0644',
        content    => template("percona/percona_cluster_checks.cfg.erb"),
    }

    # The newline in this file is important, DO NOT REMOVE IT!
    file { '/etc/sudoers.d/nagios':
        ensure => 'present',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
        content => "nagios  ALL=(ALL) NOPASSWD:${_script_path}
",
    }
}
