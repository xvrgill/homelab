#!/bin/bash
set -e

echo "Enabling IP forwarding..."

echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p

echo "IP forwarding enabled"
