#!/bin/bash

cd /var/www/html

service mysql start

if [ ! -f /var/www/html/config.inc.php ]; then
    echo "config.inc.php does not exist. starting installation ..."

    cd /var/www/html

    # js modules
    npm install -y
    npm run build

    # php modules
    composer install -v -d lib/pkp
    composer install -v -d plugins/paymethod/paypal

    # configuration
    cp config.TEMPLATE.inc.php config.inc.php
    sed -i 's/installed = Off/installed = On/' config.inc.php
    sed -i 's|base_url = "https://publications.dainst.org/books"|base_url = "http://localhost:4444"|' config.inc.php
	sed -i 's/allowProtocolRelative = false/allowProtocolRelative = true/' /var/www/html/lib/pkp/classes/core/PKPRequest.inc.php # TODO: ammend repository and remove this sed?
    sed -i "s|config->set('Cache.SerializerPath', 'cache')|config->set('Cache.SerializerPath', '/tmp/cache')|" /var/www/html/lib/pkp/classes/core/PKPString.inc.php
    sed -i "s|return Core::getBaseDir() . DIRECTORY_SEPARATOR . 'cache';|return '/tmp/cache';|" /var/www/html/lib/pkp/classes/cache/CacheManager.inc.php # TODO: ammend repository and remove this sed? probably best to read an environment variable in PHP

    chgrp -f -R www-data plugins
    setfacl -Rm o::x,d:o::x plugins
    setfacl -Rm g::rwx,d:g::rwx plugins

    chown -f -R www-data /var/www/files
    setfacl -Rm o::x,d:o::x /var/www/files
    setfacl -Rm g::rwx,d:g::rwx /var/www/files
fi

apachectl -DFOREGROUND
