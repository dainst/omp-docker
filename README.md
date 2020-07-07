# OMP Docker

There are two docker configurations: 
1. Creating a new OMP instance using OMP's installation interface.
2. Using a mysqldump of an existing OMP instance for development.

## 1. New OMP instance

### Initialize the submodules

`git submodule update --init --recursive`

### Setup the omp container

`docker-compose -f docker-compose.install.yml build`

`docker-compose -f docker-compose.install.yml up`

### Installation 

Open [localhost:4444](http://localhost:4444) and follow the installation.

Important:
* Use mysqli instead of mysql
* Use 127.0.0.1 instead of localhost for mysqli
* Set omp password as defined in config.TEMPLATE.inc.php
* Do __NOT__ create a new database (this was already done in Dockerfile-install)

### Export the installed database with
`docker exec omp_install /usr/bin/mysqldump omp > mysql_data/omp.sql`

## 2. Using an previously exported database

The scripts expects a OMP mysqldump in [mysql_data](mysql_data) named `omp.sql`.

### Initialize the submodules

`git submodule update --init --recursive`

### Setup the omp container

`docker-compose build`

`docker-compose up`

Troubleshooting (Windows): standard_init_linux.go:211: exec user process caused "no such file or directory"
* change EOL conversion for docker-entrypoint.sh. and docker-entrypoint-install.sh => change from CRLF (Windows) to LF (Linux), 
  s. https://stackoverflow.com/questions/51508150/standard-init-linux-go190-exec-user-process-caused-no-such-file-or-directory

Open [localhost:4444](http://localhost:4444), you should be able to login. Changes on the host system should be applied in the 
running instance.
