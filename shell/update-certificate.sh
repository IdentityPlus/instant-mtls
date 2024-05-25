#!/bin/bash

if !(crontab -l | grep -q update-certificate.sh) ; then
    DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    echo "installing service update cron job for 4AM every three days"    
    (crontab -l ; echo "0 4 */3 * * $DIR/update-certificate.sh") | sort - | uniq - | crontab -
fi

echo -n "updating service identity ... "
cat /etc/letsencrypt/live/plus.link/privkey.pem /etc/letsencrypt/live/plus.link/fullchain.pem > /etc/plus.link/service/plus.link.pem
service haproxy reload

