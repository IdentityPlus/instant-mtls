FROM openresty/openresty:jammy-amd64

ARG token

RUN apt update
RUN apt install -y cron python3 python3-pip golang
RUN pip3 install pyyaml

# configure Identity Plus
RUN mkdir /opt/identity.plus

# configurre the Identity Plus command line interface
RUN mkdir /opt/identity.plus/cli
RUN curl https://raw.githubusercontent.com/IdentityPlus/cli/main/agents.go > /opt/identity.plus/cli/agents.go
RUN curl https://raw.githubusercontent.com/IdentityPlus/cli/main/identityplus.go > /opt/identity.plus/cli/identityplus.go
WORKDIR /opt/identity.plus/cli
RUN go mod init identityplus
RUN go build

# autoproviion the agent mTLS ID
RUN mkdir /etc/instant-mtls
RUN mkdir /var/cache/instant-mtls

RUN ./identityplus -f /etc/instant-mtls -d "Service-Agent" enroll-service-device ${token}
RUN ./identityplus -f /etc/instant-mtls -d "Service-Agent" issue-service-identity
RUN curl https://platform.identity.plus/download/trust-chain?format=pem --cert /etc/instant-mtls/Service-Agent.cer --key /etc/instant-mtls/Service-Agent.key > /etc/instant-mtls/identity-plus-trust-store.pem
RUN ls /etc/instant-mtls/service-id | grep .cer | sed "s/.cer//" > /etc/instant-mtls/service-id/domain

# get the Identity Plus Lua integration
RUN mkdir /opt/identity.plus/instant-mtls
RUN mkdir /opt/identity.plus/instant-mtls/shell
RUN curl https://raw.githubusercontent.com/IdentityPlus/instant-mtls/blob/master/instant-mtls/config.lua > /opt/identity.plus/instant-mtls/config.lua
RUN curl https://raw.githubusercontent.com/IdentityPlus/instant-mtls/blob/master/instant-mtls/identityplus.lua > /opt/identity.plus/instant-mtls/identityplus.lua

# install identity refresh automation
RUN curl https://raw.githubusercontent.com/IdentityPlus/cli/main/update-agent.sh > /opt/identity.plus/cli/update-agent.sh
RUN chmod o+x /opt/identity.plus/cli/update-agent.sh
RUN exec ./update-agent.sh /etc/instant-mtls "Service-Agent"

RUN curl https://raw.githubusercontent.com/IdentityPlus/instant-mtls/master/shell/update-service.sh > /opt/identity.plus/instant-mtls/shell/update-service.sh
RUN chmod o+x /opt/identity.plus/instant-mtls/shell/update-service.sh
WORKDIR /opt/identity.plus/instant-mtls/shell
RUN exec ./update-service.sh /etc/instant-mtls "Service-Agent"

COPY nginx.conf.template /usr/local/openresty/nginx/conf/
RUN rm /usr/local/openresty/nginx/conf/nginx.conf
RUN mv /usr/local/openresty/nginx/conf/nginx.conf.template /usr/local/openresty/nginx/conf/nginx.conf
RUN sed -i "s/\${domain}/$(cat /etc/instant-mtls/service-id/domain)/g" /usr/local/openresty/nginx/conf/nginx.conf
