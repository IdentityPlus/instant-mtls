# configure headers to be forwarded upstream
proxy_set_header    X-Forwarded-For $remote_addr;
proxy_set_header    X-Client-Ip $remote_addr;
proxy_set_header    X-NginX-Proxy true;

real_ip_header X-Real-IP;
proxy_connect_timeout 300;

# To support websocket
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

chunked_transfer_encoding off;
