# Creating a new database

## Setup the omp container

docker-compose -f docker-compose.install.yml build

docker-compose -f docker-compose.install.yml up

## Installation 

Important:
* Use mysqli instead of mysql
* Use 127.0.0.1 instead of localhost for mysqli
* Set omp password as defined in config.TEMPLATE.inc.php
* Do __NOT__ create a new database (this was already done in Dockerfile-install)

## Export the installed database with
docker exec omp_install /usr/bin/mysqldump omp > mysql_data/omp.sql

# Using an previously exported database

TODO
