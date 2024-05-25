#!/bin/bash

if !(crontab -l | grep -q update-service.sh) ; then
    DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    echo "installing service update cron job for 4AM every daily"    
    (crontab -l ; echo "0 4 * * * $DIR/update-service.sh $1 $2") | sort - | uniq - | crontab -
fi

echo -n "updating service identity ... "
RESULT_S=$( /opt/identityplus/cli/identityplus -f $1/agent-id -d $2 update-service )
echo $RESULT_S

if [[ $RESULT_S == "renewed" ]]
    then
	echo "reloading openresty nginx service ... "
        service openresty reload
	echo "done."
    else
	echo "nothing to do ..."
    fi
