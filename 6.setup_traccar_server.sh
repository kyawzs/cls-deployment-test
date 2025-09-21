#!/bin/bash

source .env
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd ${SCRIPT_DIR}

read -p "This will install download and install Traccar Server at default port:8082 (Don't need to add for all instances), Do you want to proceed? (yes/no) " yn

case $yn in 
        yes ) echo env confirmed;;
        no ) echo exiting...;
                exit;;
        * ) echo invalid response;
                exit 1;;
esac

traccar_dir=${SCRIPT_DIR}/data/traccar
if [ -d ${traccar_dir} ]
then
echo "Traccar server installed already, Please uninstall traccar server manually and try again"
else
echo "Preparing Traccar directory.."
sudo ufw allow 8082
sudo ufw allow 5093
sudo ufw reload
mkdir -p ${traccar_dir}
cd ${traccar_dir}
sudo rm * -R
echo "Downloading Traccar Installer.."
wget ${traccar_installer}

unzip *.zip

echo "Installing Traccar Server and Starting Service.."
sudo ./traccar.run 
sudo systemctl start traccar

echo "Before setting traccar server to tracking devices, Please contact hosting administrator to enable following netwrok ports."
echo "PORT 8082 TCP INBOUND"
echo "PORT 8082 UDP INBOUND"
echo "PORT 8082 UDP OUTBOUND"
fi

