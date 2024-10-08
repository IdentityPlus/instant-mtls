#!/bin/sh

# disable password login for ssh
sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication no/g' /etc/ssh/sshd_config
service sshd restart

# install the necessary software
apt-get update
apt-get upgrade -y
apt-get install -y dnsutils mc ufw htop ca-certificates golang

# configre firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow in on eth0 to any port 22

# provision the identity plus cli
mkdir /opt/identity.plus
cd /opt/identity.plus
git clone https://github.com/IdentityPlus/cli.git
cd cli
chmod o+x update-agent.sh
mkdir -p /media/Work/Temp/IDP-Demo

# ---------------------------------------------------------
# this will be manual from here on
cd /opt/identity.plus/cli
go build

# issue the mTLS ID for this machine
./identityplus -f /media/Work/Temp/IDP-Demo -d 1Party enroll AUTOPROVISION-TOKEN-FROM-IDENTITY_PLUS

# get the trust store (identity is needed)
./identityplus -f /media/Work/Temp/IDP-Demo -d 1Party get-trust-chain

# install identity rotation automation
./update-agent.sh /media/Work/Temp/IDP-Demo 1Party


# internal client demo calls
curl https://10.0.0.2:9000/private/content.txt
curl https://minio-service.rbac.instant.mtls.app/private/content.txt --cert /media/Work/Temp/IDP-Demo/1Party.cer --key /media/Work/Temp/IDP-Demo/1Party.key --cacert /media/Work/Temp/IDP-Demo/service-id/identity-plus-root-ca.cer
curl https://minio-service.rbac.instant.mtls.app/identityplus/diagnose --cert /media/Work/Temp/IDP-Demo/1Party.cer --key /media/Work/Temp/IDP-Demo/1Party.key --cacert /media/Work/Temp/IDP-Demo/service-id/identity-plus-root-ca.cer
./identityplus -f /media/Work/Temp/IDP-Demo -d 1Party update 
./identityplus -f /media/Work/Temp/IDP-Demo -d 1Party renew 
curl https://minio-service.rbac.instant.mtls.app/identityplus/diagnose --cert /media/Work/Temp/IDP-Demo/1Party.cer --key /media/Work/Temp/IDP-Demo/1Party.key --cacert /media/Work/Temp/IDP-Demo/service-id/identity-plus-root-ca.cer


# 4rd party client demo calls
./identityplus -f /media/Work/Temp/IDP-Demo -d 3Party enroll 
curl https://minio-external.rbac.instant.mtls.app/private/content.txt --cert /media/Work/Temp/IDP-Demo/3Party.cer --key /media/Work/Temp/IDP-Demo/3Party.key --cacert /media/Work/Temp/IDP-Demo/service-id/identity-plus-root-ca.cer
curl https://minio-external.rbac.instant.mtls.app/identityplus/diagnose --cert /media/Work/Temp/IDP-Demo/3Party.cer --key /media/Work/Temp/IDP-Demo/3Party.key --cacert /media/Work/Temp/IDP-Demo/service-id/identity-plus-root-ca.cer
./identityplus -f /media/Work/Temp/IDP-Demo -d 3Party renew