#!/bin/bash

# Create the file repository configuration:
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Import the repository signing key:
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Update the package lists:
apt-get update

# Install the latest version of PostgreSQL.
# If you want a specific version, use 'postgresql-12' or similar instead of 'postgresql':
apt-get -y install postgresql-12

# Install cstore-fdw
apt-get install -y protobuf-c-compiler
apt-get install -y libprotobuf-c-dev
sed -i 's/\#shared_preload_libraries = '\'''\''/shared_preload_libraries = '\''cstore_fdw'\''/g' /etc/postgresql/12/main/postgresql.conf
sed -i 's/\#listen_addresses = '\''localhost'\''/listen_addresses = '\''10.157.20.13'\''/g' /etc/postgresql/12/main/postgresql.conf
apt-get install postgresql-12-cstore-fdw
systemctl stop postgresql
ln -s /usr/lib/postgresql/12/bin/* /usr/sbin/

# Install Patroni
apt-get install -y python3-pip python3-dev libpq-dev
sudo -H pip3 install --upgrade pip
pip install patroni
pip install python-etcd
pip install psycopg2-binary

# Configure Patroni
cat <<EOF > /etc/patroni.yml
scope: postgres
namespace: /db/
name: postgresql0

restapi:
    listen: 10.157.20.13:8008
    connect_address: 10.157.20.13:8008

etcd:
    host: 10.157.20.20:80

bootstrap:
    dcs:
        ttl: 30
        loop_wait: 10
        retry_timeout: 10
        maximum_lag_on_failover: 1048576
        postgresql:
            use_pg_rewind: true

    initdb:
    - encoding: UTF8
    - data-checksums

    pg_hba:
    - host replication replicator 127.0.0.1/32 md5
    - host replication replicator 10.157.20.12/0 md5
    - host replication replicator 10.157.20.13/0 md5
    - host all all 0.0.0.0/0 md5

    users:
        admin:
            password: admin
            options:
                - createrole
                - createdb

postgresql:
    listen: 10.157.20.13:5432
    connect_address: 10.157.20.13:5432
    data_dir: /data/patroni
    pgpass: /tmp/pgpass
    authentication:
        replication:
            username: replicator
            password: password
        superuser:
            username: postgres
            password: password
    parameters:
        unix_socket_directories: '.'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false
EOF

mkdir -p /data/patroni
chown postgres:postgres /data/patroni
chmod 700 /data/patroni

cat <<EOF > /etc/systemd/system/patroni.service
[Unit]
Description=Runners to orchestrate a high-availability PostgreSQL
After=syslog.target network.target

[Service]
Type=simple

User=postgres
Group=postgres

ExecStart=/usr/local/bin/patroni /etc/patroni.yml

KillMode=process

TimeoutSec=30

Restart=no

[Install]
WantedBy=multi-user.targ
EOF

systemctl start patroni
