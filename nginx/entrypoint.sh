#!/bin/sh
dnsmasq -u root
nginx -c /nginx.conf
