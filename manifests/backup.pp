#
class percona::backup (
    $db_user,
    $db_password,
    $db_servers,
    $use_memory = '128M', # conservative amount, prolly best to set this to the innodb bufferpool size
    $backup_hour,
    $backup_minute,
    $rotate_hour,
    $rotate_minute,
) {

    file { '/usr/local/sbin/simple_backup.sh':
        owner   => 'root',
        group   => 'root',
        mode    => '0750',
        content => template('percona/simple_backup.sh.erb')
    }

    file { '/usr/local/sbin/simple_restore.sh':
        owner   => 'root',
        group   => 'root',
        mode    => '0750',
        content => template('percona/simple_restore.sh.erb')
    }

    cron { 'run simple database backup':
        command => '/usr/local/sbin/simple_backup.sh > /var/log/simple_backup.log 2>&1',
        user    => 'root', # no other user possible, realistically
        hour    => $backup_hour,
        minute  => $backup_minute,
    }

    cron { 'rotate database backups locally':
        command => '/usr/local/sbin/rotate_backup.py /opt/backup/database/ --verbose --date-format="\%Y-\%m-\%d" --regex="^(?P<date>\d{4}-\d{2}-\d{2})_(?P<time>\d{2}-\d{2}-\d{2})$" >> /var/log/backup_rotation.log 2>&1',
        user    => 'root', # no other user possible, realistically
        hour    => $rotate_hour,
        minute  => $rotate_minute,
    }

}
