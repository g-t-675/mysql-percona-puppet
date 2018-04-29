# == Define: percona::database
#
# Ensure de creation or dropping of a particular database. The name of the
# database is based on the name of the resource.
#
# === Parameters
#
# [*ensure*]
#   Either 'present' or 'absent'
#
# [*host*]
#   The hostname or IP of the databaseserver to connect to.
#
# [*user*]
#   Use this user to make the database. For localhost a defaultsfile may be
#   used.
#
# [*password*]
#   Password of the above user.
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
define percona::database(
    $ensure,
    $host       = 'localhost',
    $user       = '',
    $password   = '',
) {
    if $ensure == present {
        $database_name  = $name
        if $host == 'localhost' {
            $mysqladmin_cmd = '/usr/bin/mysqladmin --defaults-file=/root/.my.cnf'
            $mysql_cmd      = '/usr/bin/mysql --defaults-file=/root/.my.cnf'
        } else {
            $mysqladmin_cmd = "/usr/bin/mysqladmin -h ${host} -u ${user} -p${password}"
            $mysql_cmd      = "/usr/bin/mysql -h ${host} -u ${user} -p${password}"
        }
        exec { "Create Percona database '${database_name}' on ${host}":
            unless  => "${mysql_cmd} ${database_name} -e exit",
            command => "${mysqladmin_cmd} create ${database_name}",
            path    => ['/bin','/usr/bin','/usr/local/bin'],
        }
    } else {
        notify {
            "WARNING: percona::database called with name = '${name}' but with ensure = '${ensure}'":
        }
    }
}

