FROM php:7.3-apache

LABEL maintainer="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL author="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL version="1.0"
LABEL description="DAI specific OMP3 Docker container with DAI specific plugins"
LABEL license="GNU GPL 3"

ENV DEBIAN_FRONTEND noninteractive
ENV OMP_PORT="8000"

ARG MYSQL_USER
ARG MYSQL_PASSWORD
ARG MYSQL_DB
ARG OMP_BRANCH
ARG ADMIN_USER
ARG ADMIN_PASSWORD
ARG ADMIN_EMAIL

### Install packes needed for installing from custom repos ###
RUN apt-get update && apt-get install -y \
    gnupg2 \
    software-properties-common \
    dirmngr \
    wget \
    apt-transport-https

### Add MariaDB repo ###
# Workaround for unreachable keyserver in DAI network...
# The alternative would be to use the mariadb-server of the default
# packages, which is version 10.1 though
# RUN apt-key adv --no-tty --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
#COPY conf/mariadb_key /tmp/mariadb_key
#RUN apt-key add /tmp/mariadb_key
#RUN add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirrors.dotsrc.org/mariadb/repo/10.3/debian stretch main'
## Add PHP repo
#RUN wget -q -O- https://packages.sury.org/php/apt.gpg | apt-key add -
#RUN echo "deb https://packages.sury.org/php/ stretch main" | tee /etc/apt/sources.list.d/php.list

### install packages ###
RUN apt-get update && apt-get install -y \
    bash-completion \
    ca-certificates \
    curl \
    openssl \
    mariadb-server \
    acl \
    build-essential \
    cron \
    expect \
    git \
    libssl-dev \
    nano \
    supervisor \
    unzip \
    expect \
    libbz2-dev \
    libcurl3-dev \
    libicu-dev \
    libedit-dev \
    libxml2-dev \
    zlib1g-dev \
    libzip-dev

RUN docker-php-ext-install \
    bcmath \
    bz2 \
    curl \
    dba \
    intl \
    json \
    mbstring \
    mysqli \
    pdo \
    pdo_mysql \
    readline \
    xml \
    zip

WORKDIR /tmp

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && apt-get -y install \
    nodejs
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer

### Configure Apache ###
# Adding configuration files
#COPY conf/php.ini /etc/php/7.3/apache2/
#COPY conf/php.ini /etc/php/7.3/cli/
#COPY conf/omp-apache.conf /etc/apache2/conf-available
#COPY conf/omp-ssl-site.conf /etc/apache2/sites-available
#COPY conf/omp-site.conf /etc/apache2/sites-available
#COPY conf/.htpasswd /etc/apache2/

# Ports
#RUN sed -i "s/^Listen 80.*\$/Listen $OMP_PORT/" /etc/apache2/ports.conf
#RUN sed -i "s/^<VirtualHost \*:80>.*\$/<VirtualHost \*:$OMP_PORT>/" /etc/apache2/sites-available/omp-site.conf

# Adding SSL keys and set access rights them
#COPY ssl/apache.crt /etc/apache2/ssl
#COPY ssl/apache.key /etc/apache2/ssl
#RUN chmod 600 -R /etc/apache2/ssl

#RUN a2ensite omp-site \
#    && a2dissite 000-default \
#    && a2enmod rewrite
#
#RUN echo "#!/bin/sh\nif [ -s /etc/apache2/sites-available/omp-ssl-site.conf ]; then\na2enmod ssl\na2ensite omp-ssl-site.conf\nfi"
#RUN ln -sf /dev/stdout /var/log/apache2/access.log \
#    && ln -sf /dev/stderr /var/log/apache2/error.log

# configure git
#RUN git config --global url.https://.insteadOf git://
#RUN git config --global advice.detachedHead false

# Add OMP installation scripts and change permissions
#COPY scripts/ompInstall.exp /root/ompInstall.exp
#RUN chmod +x /root/ompInstall.exp

### Initialize MySQl database ###
#RUN service mysql start && \
#    echo "CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';" | mysql -u root && \
#    echo "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE User='${MYSQL_USER}'; FLUSH PRIVILEGES;" | mysql -u root && \
#    echo "CREATE DATABASE ${MYSQL_DB};" | mysql -u root && \
#    echo "GRANT ALL PRIVILEGES on ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost'; FLUSH PRIVILEGES;" | mysql -u root

### Install OMP ###
RUN mkdir -p /var/www/files
COPY omp /var/www/html

WORKDIR /var/www/html

# php modules
RUN composer install -v -d lib/pkp --no-dev
RUN composer install -v -d plugins/paymethod/paypal --no-dev

# js modules
RUN npm install -y
RUN npm run build

# config file
RUN cp config.TEMPLATE.inc.php config.inc.php

# initial file rights
WORKDIR /var
RUN chgrp -f -R www-data www && \
    chmod -R 771 www && \
    chmod g+s www && \
    setfacl -Rm o::x,d:o::x www && \
    setfacl -Rm g::rwx,d:g::rwx www

# run installer
#WORKDIR /var/www
#RUN service mysql start
#RUN expect /root/ompInstall.exp ${ADMIN_USER} ${ADMIN_PASSWORD} ${ADMIN_EMAIL} ${MYSQL_USER} ${MYSQL_PASSWORD} ${MYSQL_DB}

### configurate OMP ### # TODO: Currently breaks installation
#WORKDIR /var/www
#RUN git clone https://github.com/dainst/ojs-config-tool ompconfig
#RUN service mysql start
# RUN php /var/www/ompconfig/omp3.php --press.theme=omp-dainst-theme --theme=omp-dainst-theme --press.plugins=themes/omp-dainst-theme,blocks/omp-dainst-nav-block

# RUN sed -i 's/allowProtocolRelative = false/allowProtocolRelative = true/' /var/www/html/lib/pkp/classes/core/PKPRequest.inc.php

# set file rights (after configuration and installation!)
WORKDIR /var/www
RUN chgrp -f -R www-data html/plugins && \
    chmod -R 771 html/plugins && \
    chmod g+s html/plugins && \
    setfacl -Rm o::x,d:o::x html/plugins && \
    setfacl -Rm g::rwx,d:g::rwx html/plugins

RUN chgrp -f -R www-data html/cache && \
    chmod -R 771 html/cache && \
    chmod g+s html/cache && \
    setfacl -Rm o::x,d:o::x html/cache && \
    setfacl -Rm g::rwx,d:g::rwx html/cache

RUN chgrp -f -R www-data html/public && \
    chmod -R 771 html/public && \
    chmod g+s html/public && \
    setfacl -Rm o::x,d:o::x html/public && \
    setfacl -Rm g::rwx,d:g::rwx html/public

RUN chgrp -f -R www-data files && \
    chmod -R 771 files && \
    chmod g+s files && \
    setfacl -Rm o::x,d:o::x files && \
    setfacl -Rm g::rwx,d:g::rwx files

### go ###
COPY ./docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80 443 3306 33060
