[Interface]
Address = 10.0.0.5/24
ListenPort = 51820
PrivateKey = ${vps_private_key}
MTU = 1500
DNS = 1.1.1.1, 1.0.0.1, 8.8.8.8

[Peer]
PublicKey = ${client_public_key}
Endpoint = ${public_ip_endpoint}:51820
AllowedIPs = 192.168.1.0/24
PersistentKeepAlive = 25