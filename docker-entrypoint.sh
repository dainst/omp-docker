#!/bin/bash

# Do not restrict mysql access to internal connections
sed -i 's|bind-address            = 127.0.0.1|bind-address            = 0.0.0.0|' /etc/mysql/mariadb.conf.d/50-server.cnf
service mysql start


echo "CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';" | mysql -u root
echo "GRANT ALL PRIVILEGES on ${MYSQL_DB}.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;" | mysql -u root

cd /var/www/html

if [ ! -f /var/www/html/config.inc.php ]; then
    echo "config.inc.php does not exist. starting installation ..."

    cd /var/www/html

    # js modules
    npm install -y
    npm run build

    # php modules
    composer install -v -d lib/pkp --no-dev
    composer install -v -d plugins/paymethod/paypal --no-dev

    # configuration
    cp config.TEMPLATE.inc.php config.inc.php
    sed -i 's/installed = Off/installed = On/' config.inc.php
    sed -i 's|base_url = "https://publications.dainst.org/books"|base_url = "http://localhost:4444"|' config.inc.php
	sed -i 's/allowProtocolRelative = false/allowProtocolRelative = true/' /var/www/html/lib/pkp/classes/core/PKPRequest.inc.php # TODO: ammend repository and remove this sed?
    sed -i "s|return Core::getBaseDir() . DIRECTORY_SEPARATOR . 'cache';|return '/tmp/cache';|" /var/www/html/lib/pkp/classes/cache/CacheManager.inc.php # TODO: ammend repository and remove this sed? probably best to read an environment variable in PHP

    chgrp -f -R www-data html/plugins
    chmod -R 771 html/plugins
    chmod g+s html/plugins
    setfacl -Rm o::x,d:o::x html/plugins
    setfacl -Rm g::rwx,d:g::rwx html/plugins


    chgrp -f -R www-data html/public
    chmod -R 771 html/public
    chmod g+s html/public
    setfacl -Rm o::x,d:o::x html/public
    setfacl -Rm g::rwx,d:g::rwx html/public

fi

apachectl -DFOREGROUND
