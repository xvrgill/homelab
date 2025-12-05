#!/usr/bin/env bash
set -e

echo "Creating wireguard server configuration..."

# Create the configuration file.
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.0.0.5/32
ListenPort = 51820
PrivateKey = $VPS_PRIVATE_KEY
MTU = 1500
DNS = 1.1.1.1, 1.0.0.1, 8.8.8.8

# Set home network wireguard instance as a peer for site-to-site vpn.
# Enables access to home network.
[Peer]
# Must replace client public key with the final one after deployment or hardcode it here
PublicKey = $CLIENT_PUBLIC_KEY
Endpoint = $PUBLIC_IP_ENDPOINT:51820
# Allow access to local network only
AllowedIPs = 192.168.1.0/24
PersistentKeepAlive = 25

# Set additional peers
EOF

echo "Configuration template created"