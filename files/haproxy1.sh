#!/bin/bash

apt-get update
apt-get install -y haproxy

cat <<EOF > /etc/haproxy/haproxy.cfg
global
    maxconn 100

defaults
    log global
    mode tcp
    retries 2
    timeout client 30m
    timeout connect 4s
    timeout server 30m
    timeout check 5s

listen stats
    mode http
    bind *:7000
    stats enable
    stats uri /

#listen pgReadWrite
#    bind *:5000
#    option pgsql-check user primaryuser
#    default-server inter 3s fall 3
#    server 10.156.10.12 10.156.10.12:5432 check port 5432
#    server 10.156.10.13 10.156.10.13:5432 check port 5432
# server 10.156.10.14 10.156.10.14:5432 check port 5432

#listen pgReadOnly
#    bind *:5001
#    option pgsql-check user standbyuser
#    default-server inter 3s fall 3
#    server 10.156.10.12 10.156.10.12:5432 check port 5432
#    server 10.156.10.13 10.156.10.13:5432 check port 5432
#    server 10.156.10.14 10.156.10.14:5432 check port 5432

listen postgres
    bind *:5000
    option httpchk
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server 10.157.20.12 10.157.20.12:5432 maxconn 100 check port 8008
    server 10.157.20.13 10.157.20.13:5432 maxconn 100 check port 8008
EOF

systemctl restart haproxy