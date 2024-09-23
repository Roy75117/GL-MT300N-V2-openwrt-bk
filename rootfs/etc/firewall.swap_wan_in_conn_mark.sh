#!/bin/sh

iptables-save -t mangle |sed '/_in_conn_mark/ s/-A PREROUTING/-I PREROUTING/' | iptables-restore -T mangle
