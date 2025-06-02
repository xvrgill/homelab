#!/usr/bin/env bash
set -e

echo "Configuring default NGINX reverse proxy..."

echo "Removing default NGINX site..."
rm -f /etc/nginx/sites-enabled/default
echo "Default NGINX site removed"

echo "Configuring NGINX as a proxy to homelab services..."

cat > /etc/nginx/sites-available/proxy << 'EOF'
# HTTP proxy configuration
# HTTP only! NGINX proxy manager handles SSL
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name _;

  # Proxy settings
  proxy_set_header HOST $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header X-Forwarded-Host $host;
  proxy_set_header X-Forwarded-Server $host;

  # Default proxy location
  # Direct to home LAN IP - router forwards traffic to proxy manager
  location / {
    proxy_pass http://192.168.1.1:80;
    proxy_connect_timeout 30s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;

    # Additional headers for better proxy manager compatibility
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_cache_bypass $http_upgrade;
  }
}

# HTTPS proxy configuration - currently disabled
# NGINX proxy manager handles SSL. No need to handle certs on VPS.
#server {
#  listen 443 ssl http2 default_server;
#  listen [::]:443 ssl http2 default_server;
#  server_name _;
#
#  # Temporary self-signed cert (replace with real certs)
#  ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
#  ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
#
#  # Forward HTTPS traffic through router to nginx proxy manager
#  location / {
#    # Router forwards traffic to proxy manager
#    proxy_pass http://192.168.1.1:443;
#    proxy_set_header Host $host;
#    proxy_set_header X-Real-IP $remote_addr;
#    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#    # Important: tell NPM this was HTTPS
#    proxy_set_header X-Forwarded-Proto https;
#    proxy_set_header X-Forwarded-Host $host;
#    proxy_set_header X-Forwarded-Server $host;
#    proxy_http_version 1.1;
#    proxy_set_header Upgrade $http_upgrade;
#    proxy_set_header Connection 'upgrade';
#    proxy_cache_bypass $http_upgrade;
#  }
#}
EOF

echo "NGINX proxy configuration file created"

echo "Enabling proxy site..."
ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/
echo "Symlink created. Proxy enabled."

echo "Testing NGINX proxy..."
nginx -t
echo "NGINX proxy test complete"

echo "NGINX proxy configuration complete"