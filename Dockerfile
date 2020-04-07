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

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

### Install packes needed for installing from custom repos ###
RUN apt-get update && apt-get install -y \
    gnupg2 \
    software-properties-common \
    dirmngr \
    wget \
    apt-transport-https

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

RUN docker-php-ext-enable mysqli

WORKDIR /tmp

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && apt-get -y install \
    nodejs
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer

### Initialize MySQl database ###
COPY mysql_data /mysql_import

RUN service mysql start && \
    echo "CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';" | mysql -u root && \
    echo "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE User='${MYSQL_USER}'; FLUSH PRIVILEGES;" | mysql -u root && \
    echo "CREATE DATABASE ${MYSQL_DB};" | mysql -u root && \
    echo "GRANT ALL PRIVILEGES on ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost'; FLUSH PRIVILEGES;" | mysql -u root && \
    echo "CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';" | mysql -u root && \
    echo "GRANT ALL PRIVILEGES on ${MYSQL_DB}.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;" | mysql -u root

# Do not restrict mysql access to internal connections
RUN sed -i 's|bind-address            = 127.0.0.1|bind-address            = 0.0.0.0|' /etc/mysql/mariadb.conf.d/50-server.cnf

RUN service mysql start && mysql -u root ${MYSQL_DB} < /mysql_import/omp.sql

### Install OMP ###
RUN mkdir -p /var/www/files

# initial file rights
WORKDIR /var
RUN chgrp -f -R www-data www && \
    chmod -R 771 www && \
    chmod g+s www && \
    setfacl -Rm o::x,d:o::x www && \
    setfacl -Rm g::rwx,d:g::rwx www

### configurate OMP ### # TODO: Currently breaks installation
#WORKDIR /var/www
#RUN git clone https://github.com/dainst/ojs-config-tool ompconfig
#RUN service mysql start
# RUN php /var/www/ompconfig/omp3.php --press.theme=omp-dainst-theme --theme=omp-dainst-theme --press.plugins=themes/omp-dainst-theme,blocks/omp-dainst-nav-block

# set file rights (after configuration and installation!)
WORKDIR /var/www

RUN chown -f -R www-data:www-data files && \
    chmod -R 771 files && \
    chmod g+s files && \
    setfacl -Rm o::x,d:o::x files && \
    setfacl -Rm g::rwx,d:g::rwx files

RUN mkdir -p /tmp/cache
RUN chown www-data:www-data /tmp/cache

RUN a2enmod rewrite

### go ###
COPY ./docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80 3306
