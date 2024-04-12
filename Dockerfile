FROM openresty/openresty:jammy-amd64


ENV PROJECT ""


RUN apt update
RUN apt install -y python3-pip golang
RUN pip3 install pyyaml

# configure Identity Plus
RUN mkdir /opt/identity.plus

# configurre the Identity Plus command line interface
RUN mkdir /opt/identity.plus/cli
RUN curl https://github.com/IdentityPlus/cli/blob/main/agents.go > /opt/identity.plus/cli/agents.go
RUN curl https://github.com/IdentityPlus/cli/blob/main/identityplus.go > /opt/identity.plus/cli/identityplus.go
RUN curl https://github.com/IdentityPlus/cli/blob/main/go.mod > /opt/identity.plus/cli/go.mod
RUN curl https://github.com/IdentityPlus/cli/blob/main/update-agent.sh > /opt/identity.plus/cli/update-agent.sh

# get the Identity Plus Lua integration
RUN mkdir /opt/identity.plus/instant-mtls
RUN curl https://github.com/IdentityPlus/instant-mtls/blob/master/instant-mtls/config.lua > /opt/identity.plus/instant-mtls/config.lua
RUN curl https://github.com/IdentityPlus/instant-mtls/blob/master/instant-mtls/identityplus.lua > /opt/identity.plus/instant-mtls/identityplus.lua
RUN curl https://github.com/IdentityPlus/instant-mtls/shell/blob/master/update-service.sh > /opt/identity.plus/instant-mtls/shell/update-service.sh

# COPY java-builder.py /opt/java-builder/
# COPY java-templates/* /opt/java-builder/java-templates/

# WORKDIR /opt/java-builder


# CMD python3 java-builder.py --config /etc/builder.identity.plus --project $PROJECT

