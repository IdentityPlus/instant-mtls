FROM openresty/openresty:jammy-amd64

ARG token
ARG config

RUN apt update
RUN apt install -y cron supervisor golang

# configure Identity Plus
RUN mkdir /opt/identity.plus

# download additional Lua modules (http in particular)
RUN opm get ledgetech/lua-resty-http

# configurre the Identity Plus mTLS Persona
RUN mkdir -p /opt/identity.plus/mtls-persona
RUN curl https://raw.githubusercontent.com/IdentityPlus/mtls-persona/main/mtls-persona.go > /opt/identity.plus/mtls-persona/mtls-persona.go
COPY persona.json /opt/identity.plus/mtls-persona/config.json
WORKDIR /opt/identity.plus/mtls-persona
RUN go mod init mtls-persona
RUN go build

# configurre the Identity Plus command line interface
RUN mkdir -p /opt/identity.plus/cli
RUN curl https://raw.githubusercontent.com/IdentityPlus/cli/main/agents.go > /opt/identity.plus/cli/agents.go
RUN curl https://raw.githubusercontent.com/IdentityPlus/cli/main/identityplus.go > /opt/identity.plus/cli/identityplus.go
WORKDIR /opt/identity.plus/cli
RUN go mod init identityplus
RUN go build

# autoproviion the agent mTLS ID
RUN mkdir /etc/instant-mtls
RUN mkdir /var/cache/instant-mtls
RUN chown www-data:www-data /var/cache/instant-mtls

# create default certificates
RUN openssl req -new -newkey rsa:2048 -days 36500 -nodes -x509 -subj '/CN=sni-support-required-for-valid-ssl' -keyout /etc/instant-mtls/resty-auto-ssl-fallback.key -out /etc/instant-mtls/resty-auto-ssl-fallback.cer

RUN ./identityplus -f /etc/instant-mtls -d "Service-Agent" enroll ${token}
RUN ./identityplus -f /etc/instant-mtls -d "Service-Agent" issue-service-identity
RUN ./identityplus -f /etc/instant-mtls -d "Service-Agent" get-trust-chain
RUN ls /etc/instant-mtls/service-id | grep .key | sed "s/.cer//" | sed "s/rbac.//"> /etc/instant-mtls/service-id/domain

# get the Identity Plus Lua integration
RUN mkdir -p /opt/identity.plus/instant-mtls/shell
COPY instant-mtls/config.lua /opt/identity.plus/instant-mtls/
COPY instant-mtls/identityplus.lua /opt/identity.plus/instant-mtls/

# install identity refresh automation
RUN curl https://raw.githubusercontent.com/IdentityPlus/cli/main/update-agent.sh > /opt/identity.plus/cli/update-agent.sh
RUN chmod o+x /opt/identity.plus/cli/update-agent.sh
RUN exec ./update-agent.sh /etc/instant-mtls "Service-Agent"

RUN curl https://raw.githubusercontent.com/IdentityPlus/cli/main/update-service.sh > /opt/identity.plus/cli/update-service.sh
RUN chmod o+x /opt/identity.plus/cli/update-service.sh
RUN exec ./update-service.sh /etc/instant-mtls "Service-Agent"

# we will map conf directory into the docker instance, but the following files (which will be referred to as defaults) will be buit into the image
COPY org-domain.conf /etc/instant-mtls/
COPY identityplus-defaults.inc /etc/instant-mtls/
COPY conf /etc/instant-mtls/conf/
RUN find /etc/instant-mtls -type f -exec sed -i "s|\${domain}|$(cat /etc/instant-mtls/service-id/domain | sed 's/[&/\]/\\&/g')|g" {} +

RUN rm /usr/local/openresty/nginx/conf/nginx.conf
COPY instant-mtls.conf /usr/local/openresty/nginx/conf/nginx.conf
RUN sed -i "s/\${domain}/$(cat /etc/instant-mtls/service-id/domain)/g" /usr/local/openresty/nginx/conf/nginx.conf

RUN echo "[supervisord]" > /etc/supervisord.conf && \
    echo "nodaemon=true" >> /etc/supervisord.conf && \
    echo "" >> /etc/supervisord.conf && \
    echo "[program:mtls-persona]" >> /etc/supervisord.conf && \
    echo "directory=/opt/identity.plus/mtls-persona" >> /etc/supervisord.conf && \
    echo "stdout_logfile=/dev/stdout" >> /etc/supervisord.conf && \
    echo "stdout_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "stderr_logfile=/dev/stderr" >> /etc/supervisord.conf && \
    echo "stderr_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "command=/opt/identity.plus/mtls-persona/mtls-persona" >> /etc/supervisord.conf && \
    echo "" >> /etc/supervisord.conf && \
    echo "[program:openresty]" >> /etc/supervisord.conf && \
    echo "stdout_logfile=/dev/stdout" >> /etc/supervisord.conf && \
    echo "stdout_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "stderr_logfile=/dev/stderr" >> /etc/supervisord.conf && \
    echo "stderr_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "command=/usr/local/openresty/bin/openresty -g 'daemon off;'" >> /etc/supervisord.conf

CMD ["/usr/bin/supervisord"]

# CMD ["/usr/local/openresty/bin/openresty -g daemon off;"]
