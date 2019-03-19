FROM debian:9.7-slim

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
COPY conf/mariadb_key /tmp/mariadb_key
RUN apt-key add /tmp/mariadb_key
RUN add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirrors.dotsrc.org/mariadb/repo/10.3/debian stretch main'
# Add PHP repo
RUN wget -q -O- https://packages.sury.org/php/apt.gpg | apt-key add -
RUN echo "deb https://packages.sury.org/php/ stretch main" | tee /etc/apt/sources.list.d/php.list

RUN apt-get update && apt-get install -y \
    bash-completion \
    ca-certificates \
    curl \
    openssl \
    apache2 \
    mariadb-server \
    libapache2-mod-php \
    php7.3 \
    php7.3-bcmath \
    php7.3-bz2 \
    php7.3-cgi \
    php7.3-cli \
    php7.3-common \
    php7.3-curl \
    php7.3-dba \
    php7.3-intl \
    php7.3-json \
    php7.3-mbstring \
    php7.3-mysql \
    php7.3-readline \
    php7.3-xml \
    php7.3-zip \
    acl \
    build-essential \
    cron \
    exiftool \
    expect \
    git \
    imagemagick \
    libssl-dev \
    nano \
    pdftk \
    supervisor \
    unzip

WORKDIR /tmp

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && apt-get -y install \
    nodejs
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer

### Configure Apache ###
# Adding configuration files
COPY conf/php.ini /etc/php/7.3/apache2/
COPY conf/php.ini /etc/php/7.3/cli/
COPY conf/omp-apache.conf /etc/apache2/conf-available
COPY conf/omp-ssl-site.conf /etc/apache2/sites-available
COPY conf/omp-site.conf /etc/apache2/sites-available
COPY conf/.htpasswd /etc/apache2/
# Ports
RUN sed -i "s/^Listen 80.*\$/Listen $OMP_PORT/" /etc/apache2/ports.conf
RUN sed -i "s/^<VirtualHost \*:80>.*\$/<VirtualHost \*:$OMP_PORT>/" /etc/apache2/sites-available/omp-site.conf
# Adding SSL keys and set access rights them
COPY ssl/apache.crt /etc/apache2/ssl
COPY ssl/apache.key /etc/apache2/ssl
RUN chmod 600 -R /etc/apache2/ssl

RUN a2ensite omp-site \
    && a2dissite 000-default \
    && a2enmod rewrite
RUN echo "#!/bin/sh\nif [ -s /etc/apache2/sites-available/omp-ssl-site.conf ]; then\na2enmod ssl\na2ensite omp-ssl-site.conf\nfi"
RUN ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log

# configure git for Entrypoint script
RUN git config --global url.https://.insteadOf git://
RUN git config --global advice.detachedHead false

# Add OMP installation scripts and change permissions
COPY scripts/ompInstall.exp /root/ompInstall.exp
RUN chmod +x /root/ompInstall.exp

### Initialize MySQl database ###
RUN service mysql start && \
    echo "CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';" | mysql -u root && \
    echo "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE User='${MYSQL_USER}'; FLUSH PRIVILEGES;" | mysql -u root && \
    echo "CREATE DATABASE ${MYSQL_DB};" | mysql -u root && \
    echo "GRANT ALL PRIVILEGES on ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost'; FLUSH PRIVILEGES;" | mysql -u root

### Initialize OMP repo ###
RUN mkdir -p /var/www/ompfiles
WORKDIR /var/www/html
RUN rm index.html
RUN git init && \
    git remote add -t ${OMP_BRANCH} origin https://github.com/pkp/omp.git && \
    git fetch origin --depth 1 ${OMP_BRANCH} && \
    git checkout --track origin/${OMP_BRANCH}
RUN git submodule update --init --recursive

RUN composer install -v -d lib/pkp --no-dev
RUN composer install -v -d plugins/paymethod/paypal --no-dev

RUN npm install -y
RUN npm run build

RUN cp config.TEMPLATE.inc.php config.inc.php
WORKDIR /var
RUN chgrp -f -R www-data www && \
    chmod -R 771 www && \
    chmod g+s www && \
    setfacl -Rm o::x,d:o::x www && \
    setfacl -Rm g::rwx,d:g::rwx www

### Install OMP ###
WORKDIR /var/www
RUN service mysql start && \
    expect /root/ompInstall.exp ${ADMIN_USER} ${ADMIN_PASSWORD} ${ADMIN_EMAIL} ${MYSQL_USER} ${MYSQL_PASSWORD} ${MYSQL_DB}

# Install OMP Plugins
WORKDIR html/plugins
##RUN git clone --single-branch -b ${OMP_BRANCH} https://github.com/asmecher/texture generic/texture TODO include texture 4 omp
##RUN git submodule update --init --recursive
##RUN chgrp -f -R www-data generic/texture && \
##    chmod -R 771 generic/texture && \
##    chmod g+s generic/texture && \
##    setfacl -Rm o::x,d:o::x generic/texture && \
##    setfacl -Rm g::rwx,d:g::rwx generic/texture



WORKDIR /var/www/html/plugins
RUN git clone -b omp3 https://github.com/dainst/ojs-cilantro-plugin.git generic/ojs-cilantro-plugin
RUN git clone -b omp3 https://github.com/dainst/ojs-zenon-plugin.git pubIds/zenon
#RUN git clone -b omp3 https://github.com/dainst/epicur.git oaiMetadataFormats/epicur
RUN git submodule update --init --recursive

# set file rights
WORKDIR /var/www/html/
RUN chgrp -f -R www-data plugins && \
    chmod -R 771 plugins && \
    chmod g+s plugins && \
    setfacl -Rm o::x,d:o::x plugins && \
    setfacl -Rm g::rwx,d:g::rwx plugins

RUN mkdir /var/www/tmp
WORKDIR /var/www
RUN chgrp -f -R www-data tmp && \
    chmod -R 771 tmp && \
    chmod g+s tmp && \
    setfacl -Rm o::x,d:o::x tmp && \
    setfacl -Rm g::rwx,d:g::rwx tmp

# config OMP
RUN git clone https://github.com/dainst/ojs-config-tool ompconfig
RUN service mysql start && \
    php -d display_errors=on /var/www/ompconfig/omp3.php
RUN sed -i 's/allowProtocolRelative = false/allowProtocolRelative = true/' /var/www/html/lib/pkp/classes/core/PKPRequest.inc.php

COPY ./docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE $OMP_PORT 443 3306 33060
