class percona::secure_installation {
    $mysql_cmd = '/usr/bin/mysql --defaults-file=/root/.my.cnf --skip-column-names --execute'

    exec { 'Remove remote \'root\' users':
        command => "${mysql_cmd} \"DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');\"",
        onlyif => "/bin/bash -c \"/usr/bin/test `${mysql_cmd} \"SELECT COUNT(1) from mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');\"` -ne 0\"",
        require => File['/root/.my.cnf'],
        notify => Exec['Reload privileges'],
    }

    exec { 'Remove anonymous users':
        command => "${mysql_cmd} \"DELETE FROM mysql.user WHERE User='';\"",
        onlyif => "/bin/bash -c \"/usr/bin/test `${mysql_cmd} \"SELECT COUNT(1) from mysql.user WHERE User=''\"` -ne 0\"",
        require => File['/root/.my.cnf'],
        notify => Exec['Reload privileges'],
    }

    exec { 'Remove \'test\' database':
        command => "${mysql_cmd} \"DROP DATABASE test;\"",
        onlyif => "/bin/bash -c \"/usr/bin/test `${mysql_cmd} \"show databases like 'test';\"` = test\"",
        require => File['/root/.my.cnf'],
        notify => Exec['Reload privileges'],
    }

    exec { 'Remove privileges on \'test\' database':
        command => "${mysql_cmd} \"DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';\"",
        onlyif => "/bin/bash -c \"/usr/bin/test `${mysql_cmd} \"SELECT COUNT(1) from mysql.db WHERE Db = 'test' OR Db = 'test\\_%';\"` -ne 0\"",
        require => File['/root/.my.cnf'],
        notify => Exec['Reload privileges'],
    }

    exec { 'Reload privileges':
        command => "${mysql_cmd} \"FLUSH PRIVILEGES;\"",
        refreshonly => true,
    }
}
