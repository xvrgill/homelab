# Immich Configuration

This is a configuration for an [Immich](https://immich.app); a self-hosted photo and video management application.

## Nginx Proxy Manager Configuration

The Immich team's [documentation](https://immich.app/docs/administration/reverse-proxy/) recommends updating the 
server/endpoint configuration. The configuration below can be added under the proxy host's advanced tab:

```
# allow large file uploads
client_max_body_size 50000M;

# Set headers
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

# This is recommended, but nginx proxy manager has a UI toggle for this.
# Ensure that `Enable websockets` is selected in the UI and skip this section.
# enable websockets: http://nginx.org/en/docs/http/websocket.html
# proxy_http_version 1.1;
# proxy_set_header   Upgrade    $http_upgrade;
# proxy_set_header   Connection "upgrade";
# proxy_redirect     off;

# set timeout
proxy_read_timeout 600s;
proxy_send_timeout 600s;
send_timeout       600s;
```

A copy of this configuration can also be found in [proxy_config.txt](./proxy_config.txt).