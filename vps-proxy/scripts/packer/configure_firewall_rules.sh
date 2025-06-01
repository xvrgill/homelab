#!/usr/bin/env bash
set -e

echo "Configuring firewall rules..."
sleep 1

cat > /etc/iptables/rules.v4 << 'EOF'
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Allow established connections
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow SSH
-A INPUT -p tcp --dport 22 -j ACCEPT

# Allow wireguard
-A INPUT -p udp --dport 51820 -j ACCEPT

# Allow http/https for nginx
-A INPUT -p tcp --dport 80 -j ACCEPT

# Allow HTTPS for nginx - currently disabled
# Certificates are all handled by nginx proxy manager
#-A INPUT -p tcp --dport 443 -j ACCEPT

# Allow wireguard tunnel traffic
-A FORWARD -i wg0 -j ACCEPT
-A FORWARD -o wg0 -j ACCEPT

COMMIT

*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]

# Only need masquerading for wireguard tunnel
# Packets from wireguard tunnel are modified to show VPS IP
-A POSTROUTING -o eth0 -s 10.0.0.0/24 -j MASQUERADE

COMMIT
EOF

echo "Firewall rules configured"
sleep 2