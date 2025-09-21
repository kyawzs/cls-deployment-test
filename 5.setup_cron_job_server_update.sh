#!/bin/bash

source .env
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd ${SCRIPT_DIR}

read -p "This will add cron job to run regular server update script (Don't need to add cron for all instances), Do you want to proceed? (yes/no) " yn

case $yn in 
        yes ) echo env confirmed;;
        no ) echo exiting...;
                exit;;
        * ) echo invalid response;
                exit 1;;
esac

echo ${SCRIPT_DIR}

sudo crontab -l > cron_bkp
sudo echo "0 0 1 1 * $(pwd)/1.setup_server.sh update >/dev/null 2>&1" >> cron_bkp
sudo crontab cron_bkp
sudo rm cron_bkp