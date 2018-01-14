#!/usr/bin/env bash

DOMAIN=${DOMAIN:-prometheus.exokube.eu}
target=$1
port=0
if [ "$target" == "dns" ]; then
	port=8080
elif [ "$target" == "consul" ]; then
	port=18080
else
	echo "Usage: $0 <dns|consul>";
	exit 1;
fi

seq 0 1 | parallel -j20 "ab -r -k -n 100000 -c 20 http://prom-node-{}.${DOMAIN}:${port}/api/query"
