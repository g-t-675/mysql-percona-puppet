# == Define: percona::rights
#
# A basic helper used to create a user and grant him some privileges on a
# database. Pretty much the same as mysql::rights and should later on be
# merged?
#
# TODO: make defaults file more configurable/overridable
#
# === Parameters
#
# Document parameters here
#
# [*ensure*] defaults to present
# [*database*] the target database
# [*user*] the target user
# [*password*] user's password
# [*host*] target host, default to "localhost"
# [*priv*] target privileges, defaults to "all" (values are the fieldnames from
#   mysql.db table).
# [*grant*] target user also gets the "grant" option
# [*db_host*] the host running the database
# [*db_user*] the user used to connect to the db_host
# [*db_password*] the password used to connect to the db_host
#
# === Examples
#
#  percona::rights { "example case":
#    user     => "foo",
#    password => "bar",
#    database => "mydata",
#    priv    => ["select_priv", "update_priv"]
#  }
#
# === Authors
#
# Proteon
#
# === Copyright
#
# Copyright 2013 Proteon
#
define percona::rights (
    $database,
    $user,
    $password,
    $host           = 'localhost',
    $ensure         = 'present',
    $priv           = 'all',
    $grant_option   = false,
    $db_host        = 'localhost',
    $db_user        = undef,
    $db_password    = undef,
) {
    $joined_privileges = $priv
    $defaults_file = '/root/.my.cnf'

    if $grant_option == true {
        $grant_option_string = ' WITH GRANT OPTION'
    } else {
        $grant_option_string = ''
    }

    if $database == '*' {
        $escquoted_database = $database
        $quoted_database    = $database
    } else {
        $escquoted_database = "\\`${database}\\`"
        $quoted_database    = "`${database}`"
    }

    if $ensure == 'present' {
        $grant_statement = "GRANT ${joined_privileges} ON ${escquoted_database}.* TO '${user}'@'${host}' IDENTIFIED BY '${password}' ${grant_option_string}"
        if $db_host == 'localhost' {
            $mysqladmin_cmd = '/usr/bin/mysqladmin --defaults-file=/root/.my.cnf'
            $mysql_cmd      = '/usr/bin/mysql --defaults-file=/root/.my.cnf'
            $required       = File['/root/.my.cnf']
        } else {
            $mysqladmin_cmd = "/usr/bin/mysqladmin -h ${db_host} -u ${db_user} -p${db_password}"
            $mysql_cmd      = "/usr/bin/mysql -h ${db_host} -u ${db_user} -p${db_password}"
            $required       = undef
        }

        exec { "create rights for ${name}" :
            command     => "${mysql_cmd} mysql -e \"${grant_statement}\" && ${mysqladmin_cmd} flush-privileges",
            unless      => "${mysql_cmd} mysql -e \"show grants for '${user}'@'${host}'\" | grep \"${quoted_database}.*\" | grep `${mysql_cmd} --skip-column-names -e \"SELECT PASSWORD('${password}')\"`",
            require     => $required,
            path        => ['/bin', '/usr/bin', '/usr/local/bin'],
            logoutput   => true,
        }
    } else {
        notify { "WARNING: percona::rights called with name = '${name}' but with ensure = '${ensure}'": }
    }
}
