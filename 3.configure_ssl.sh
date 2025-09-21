#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd ${SCRIPT_DIR}
source ${SCRIPT_DIR}/.env
host ${domain}
if [ "$1" = "y" ]
 then
   echo "setting up SSL.."
   sudo certbot --apache --agree-tos --redirect -m ${contact} -d ${domain}

   echo "Reloading Web server..."
   sudo systemctl restart apache2

   echo "Lets Encrypt Certificate setup complete." 
else
echo "Please setup above IP address as A/AAA DNS entry in domain setting before setting up SSL. Press any key to continute"
while [ true ] ; do
read -t 3 -n 1
if [ $? = 0 ] ; then
echo "setting up SSL.."
sudo certbot --apache --agree-tos --redirect -m ${contact} -d ${domain}

echo "Reloading Web server..."
sudo systemctl restart apache2

echo "Lets Encrypt Certificate setup complete."
exit ;
else
echo "waiting.."
fi
done
fi