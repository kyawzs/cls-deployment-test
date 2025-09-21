#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd ${SCRIPT_DIR}
source ${SCRIPT_DIR}/.env

echo "Welcome to CLS Pase 1 Installer 1.0.0."
echo "This will install server and setup CLS Phase 1 Project based on following environment settings from ./env file."
echo ""
echo "Domain = ${domain}"
echo "Database = ${db}"
echo "Database User = ${user}"
echo "Admin Email = ${contact}"
echo "CLS Project Repository = ${repo}"
echo "Repository Branch = {$branch}"
echo ""
if [ "$1" = "update" ]
 then
 echo "Update mode.."
 else
read -p "Do you want to proceed? (yes/no) " yn
case $yn in 
	yes ) echo env confirmed;;
	no ) echo exiting...;
		exit;;
	* ) echo invalid response;
		exit 1;;
esac
fi

echo "Updating system.."
#sudo apt update -y
#sudo apt upgrade -y

export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
sudo -E apt-get -qy update
sudo -E apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
sudo -E apt-get -qy autoclean

echo "Installing Apache Web Server.."
sudo apt install git apache2 -y
echo "Allowing Web server ports in Firewall..."
sudo ufw allow 'Apache Full'
sudo ufw reload

echo "Installing MySql Database Server..."
sudo apt install mysql-server -y
#sudo apt install php libapache2-mod-php php7.4-mysql php7.4-common php7.4-mysql php-xml php7.4-xmlrpc php7.4-curl php-gd php7.4-imagick php7.4-cli php7.4-dev php7.4-imap php7.4-mbstring php7.4-opcache php7.4-soap php7.4-zip php7.4-intl php-xml -y 

echo "Installing PHP and Extenstions..."
sudo apt install php libapache2-mod-php php-mysql php-common php-mysql php-xml php-xmlrpc php-curl php-gd php-imagick php-cli php-dev php-imap php-mbstring php-opcache php-soap php-zip php-intl php-xml -y 
if [ "$1" = "update" ]
 then
 echo "Configuration setting skipped for update mode"
 else
ssh-keyscan github.com >>~/.ssh/known_hosts

sudo a2dissite 000-default
echo "Enabling Apache Mods..."
#sudo a2enmod rewrite
sudo a2enmod ssl proxy_http proxy_wstunnel rewrite

#sudo apt install composer -y
echo "Installing curl and Composer V2..."
sudo apt install curl
sudo curl -s https://getcomposer.org/installer | php
sudo mv composer.phar /usr/bin/composer
sudo apt install python3-certbot-apache -y

echo "Checking SSH key..."
SSHKEY=~/.ssh/id_rsa.pub
if [ -f "$SSHKEY" ]; then
    echo "$SSHKEY exists."
   
else 
    echo "$SSHKEY does not exist, Please follow the screen instruction to genenrate ssh key.."
    ssh-keygen
fi
#if [ -f "$SSHKEY" ]; then
#   echo "Please contact admin to enable following ssh deployment key at repository ${repo}."
#   echo "After setting up deployment key, you can proceed to next setp 2.configure_project."
#   cat $SSHKEY
#else 
#  echo ""
#fi
echo ""
#echo 'Please proceed to next step to configure the project'
fi

echo 'Setting Default PHP INI settings..'
INI_LOC=$(php -i|sed -n '/^Loaded Configuration File => /{s:^.*> ::;p;q}')
upload_max_filesize=400M
post_max_size=200M
max_execution_time=3000
max_input_time=5000

for key in upload_max_filesize post_max_size max_execution_time max_input_time
do
sed -i "s/^\($key\).*/\1 $(eval echo = \${$key})/" ${INI_LOC}
done

echo "Please contact admin to enable following ssh deployment key at repository ${repo} if not setup."
   echo "After setting up deployment key, you can proceed to next setp 2.configure_project."
   cat $SSHKEY
#echo 'update .env file before proceeding to next step.'

if [ "$1" = "complete" ]
 then
 echo "Complete Mode.."
 ${SCRIPT_DIR}/2.configure_project.sh
 ${SCRIPT_DIR}/3.configure_ssl.sh y
 ${SCRIPT_DIR}/4.setup_cron_job_backup_maintanance.sh y
fi