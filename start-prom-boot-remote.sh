#!/usr/bin/env bash

type=$1

for instance in 0 1; do
	if [ "$type" == "dns" ]; then
		ssh "prom-node-${instance}.prometheus.exokube.eu" prom-boot-dns;
	elif [ "$type" == "consul" ]; then
		ssh "prom-node-${instance}.prometheus.exokube.eu" prom-boot-consul;
	else
		echo "'${type}' is not a valid prom-boot discovery mode.";
		exit 1;
	fi
done


