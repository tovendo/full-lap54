#!/bin/bash
# We'll say that we are by default in dev
php5enmod xdebug
sed -i 's/^display_errors\s*=.*/display_errors = On/g' /etc/php5/apache2/conf.d/30-custom-php.ini
sed -i 's/^max_execution_time\s*=.*/max_execution_time = -1/g' /etc/php5/apache2/conf.d/30-custom-php.ini

# If prod has been set ... "clean"
if [ "$ENVIRONMENT" != "dev" ]; then
    php5dismod xdebug
    sed -i 's/^display_errors\s*=.*/display_errors = Off/g' /etc/php5/apache2/conf.d/30-custom-php.ini
    sed -i 's/^max_execution_time\s*=.*/max_execution_time = 60/g' /etc/php5/apache2/conf.d/30-custom-php.ini
fi

ping_apache() {
    (exec 6<>/dev/tcp/127.0.0.1/80 ) >/dev/null 2>&1
}

check_service() {
    local service="$1"
    local ping_cmd="$2"
    echo -n "Check $service "
    for retry in {1..100}
    do
        $ping_cmd
        if [ "$?" -eq "0" ]
        then
            echo " $service Started"
            break
        fi
        echo -n "."
        sleep .1
    done
    if [ "$retry" -eq "100" ]
    then
        echo " Unable to start $service"
        exit 1
    fi
}

if [ "x$1" == "x--detach" ]
then
    /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
    # Test if apache is started
    check_service Apache "ping_apache"
else
    exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf --nodaemon
fi
