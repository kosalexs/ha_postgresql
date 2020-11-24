#!/bin/bash

apt-get update
apt-get install -y etcd

set ETCD_ENABLE_V2=true

cat <<EOF > /etc/default/etcd
ETCD_INITIAL_CLUSTER="bhuvi-etcd1=http://10.157.20.10:2380,bhuvi-etcd2=http://10.157.20.11:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.157.20.10:2380"
#ETCD_DATA_DIR="/var/etcd"
ETCD_LISTEN_PEER_URLS="http://10.157.20.10:2380"
ETCD_LISTEN_CLIENT_URLS="http://10.157.20.10:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://10.157.20.10:2379,http://127.0.0.1:2379"
ETCD_NAME="bhuvi-etcd1"
EOF

service etcd restart