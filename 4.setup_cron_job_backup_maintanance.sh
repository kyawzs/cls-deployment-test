#!/bin/bash

source .env
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd ${SCRIPT_DIR}

if [ "$1" = "y" ]
 then
        echo "Direct mode"
 else
read -p "This will add cron job to backup datbase and run regular maintanance script, Do you want to proceed? (yes/no) " yn

case $yn in 
        yes ) echo env confirmed;;
        no ) echo exiting...;
                exit;;
        * ) echo invalid response;
                exit 1;;
esac
fi

echo "Setting cron jobs for database backup.."
sudo chmod +x ${SCRIPT_DIR}/data/db_backup.sh
crontab -l > cron_bkp
echo "0 */6 * * * ${SCRIPT_DIR}/data/db_backup.sh >/dev/null 2>&1" >> cron_bkp
crontab cron_bkp
rm cron_bkp

echo "Setting cron jobs for maintanance script.."
sudo chmod +x ${SCRIPT_DIR}/data/maintanance.sh
crontab -l > cron_bkp
echo "0 0 * * 0 ${SCRIPT_DIR}/data/maintanance.sh >/dev/null 2>&1" >> cron_bkp
crontab cron_bkp
rm cron_bkp
