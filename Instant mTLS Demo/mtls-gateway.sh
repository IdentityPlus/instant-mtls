#!/bin/sh

# disable password login for ssh
sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication no/g' /etc/ssh/sshd_config
service sshd restart

# Add Docker the repository to Apt sources:
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# install the necessary software
apt-get update
apt-get upgrade -y
apt-get install -y dnsutils mc ufw htop ca-certificates docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# configre firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow in on eth0 to any port 22
ufw allow in on eth0 to any port 443
ufw allow in on enp70s to any port 443
