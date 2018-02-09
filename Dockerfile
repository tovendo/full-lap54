FROM debian:wheezy-slim
RUN echo 'deb http://ftp.br.debian.org/debian wheezy-backports contrib main non-free' > /etc/apt/sources.list.d/backports.list

# Create man directory to avoid java to crash on install
RUN mkdir -p /usr/share/man/man1

# Install Apache + PHP
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates supervisor wget \
    unzip php-pear apt-utils libaio-dev php5-dev php5-pspell php5-snmp php5-xmlrpc \
    php5-recode php5-common php5-gmp build-essential \
    php5-mongo php5-mysqlnd libmcrypt-dev make \
    apache2 \
    libapache2-mod-php5 php-apc php5-cli php5-curl php5-gd php5-geoip php5-imagick php5-imap \
    php5-intl php5-json php5-ldap php5-mcrypt php5-memcached php5-odbc php5-pgsql \
    php5-sqlite php5-tidy php5-xdebug php5-xsl && \
    DEBIAN_FRONTEND=noninteractive apt-get clean && \
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y && \
    rm -Rf /var/lib/apt/lists/* /usr/share/man/* /usr/share/doc/*

# Prepare PHP
COPY php-cli.ini /etc/php5/cli/conf.d/30-custom-php.ini
COPY php-apache.ini /etc/php5/apache2/conf.d/30-custom-php.ini
RUN mkdir -p /var/log/php
RUN chown -R www-data:www-data /var/log/php
RUN php -r "copy('https://getcomposer.org/download/1.5.1/composer.phar', '/usr/local/bin/composer');" && \
    php -r "if (hash_file('SHA384', '/usr/local/bin/composer') === 'fd3800adeff12dde28e9238d2bb82ba6f887bc6d718eee3e3a5d4f70685a236b9e96afd01aeb0dbab8ae6211caeb1cbe') {echo 'Composer installed';} else {echo 'Hash invalid for downloaded composer.phar'; exit(1);}" && \
    chmod 0755 /usr/local/bin/composer && \
    /usr/local/bin/composer selfupdate --stable

# Prepare Apache
RUN mkdir -p /var/www/html
RUN mv /var/www/index.html /var/www/html/
RUN sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/sites-available/default*
RUN sed -i "s/\/var\/www/\/var\/www\/html/g" /etc/apache2/sites-available/default*
RUN a2enmod rewrite
EXPOSE 80

# Install the Oracle Instant Client
ADD oracle/oracle-instantclient-basic_10.2.0.5-2_amd64.deb /tmp
ADD oracle/oracle-instantclient-devel_10.2.0.5-2_amd64.deb /tmp
ADD oracle/oracle-instantclient-sqlplus_10.2.0.5-2_amd64.deb /tmp
RUN dpkg -i /tmp/oracle-instantclient-basic_10.2.0.5-2_amd64.deb
RUN dpkg -i /tmp/oracle-instantclient-devel_10.2.0.5-2_amd64.deb
RUN dpkg -i /tmp/oracle-instantclient-sqlplus_10.2.0.5-2_amd64.deb
RUN rm -rf /tmp/oracle-instantclient-*.deb

# Set up the Oracle environment variables
ENV LD_LIBRARY_PATH /usr/lib/oracle/10.2.0.5/client64/lib/
ENV ORACLE_HOME /usr/lib/oracle/10.2.0.5/client64/lib/
RUN export ORACLE_HOME=/usr/lib/oracle/10.2.0.5/client64/lib/
RUN echo $ORACLE_HOME 

# Install the OCI8 PHP extension
ADD oracle/oci8-1.4.10.zip /tmp
RUN mkdir -p /usr/lib/oracle/src
RUN unzip /tmp/oci8-1.4.10.zip -d /usr/lib/oracle/src
RUN cd /usr/lib/oracle/src/oci8-1.4.10/oci8-1.4.10 && \
    phpize && \
    ./configure --with-oci8=instantclient,/usr/lib/oracle/10.2.0.5/client64/lib && \
    make install
RUN echo 'extension=oci8.so' > /etc/php5/apache2/conf.d/20-oci8.ini
RUN echo 'extension=oci8.so' >> /etc/php5/apache2/php.ini

# Command
COPY run.sh /run.sh
RUN chmod +x /run.sh

ENV ENVIRONMENT dev

# Prepare supervisor
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Last step for services
CMD ["/run.sh"]
