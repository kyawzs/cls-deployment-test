#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd ${SCRIPT_DIR}
source ${SCRIPT_DIR}/.env

echo "Setting up environment variables in ./data/db.sql..."
sed -i "s/__DOMAIN__/${domain}/g" ./data/db.sql
sed -i "s/__DB__/${db}/g" ./data/db.sql
#sed -i "s/__DBHOST__/${db_host}/g" ./data/db.sql
sed -i "s/__USER__/${user}/g" ./data/db.sql
sed -i "s/__PASS__/${pass}/g" ./data/db.sql

echo "Preparing MySQL Database and User..."
sudo mysql < ./data/db.sql

sudo a2dissite ${domain}
sudo chown -R www-data: /var/www/
sudo apt-get install -y acl
sudo setfacl -R -m u:$USER:rwx /var/www
if [ "$1" = "" ]
then
    sudo cp ./data/000-default.conf /etc/apache2/sites-available/${domain}.conf
else
    echo "Skip domain configuration.."
fi

cd /var/www
ssh-keyscan github.com >>~/.ssh/known_hosts

Directory=/var/www/${domain}
if [ -d "$Directory" ]
then
	echo "found repo.."
    if [ "$1" = "reset" ]
    then
        echo "project reset mode"
        echo "cleaning existing site..."
        sudo rm -R /var/www/${domain}
        git clone -b ${branch} ${repo} ${domain}
        git config --global --add safe.directory /var/www/d1.cls-cdema.org
    else
        cd ${domain}
        echo "Updating latest repository..."
        git stash && git pull origin ${branch}eeee
    fi
   
else
    echo "Cloning Git repository into branch ${branch}..."
    git clone -b ${branch} ${repo} ${domain}
    git config --global --add safe.directory /var/www/d1.cls-cdema.org
fi

cd ${domain}

cp ./.env.example ./.env
echo "Updating environment variables for laravel..."
sed -i "s/__DOMAIN__/${domain}/g" /var/www/${domain}/.env
sed -i "s/__DB__/${db}/g" /var/www/${domain}/.env
sed -i "s/__DBHOST__/${db_host}/g" /var/www/${domain}/.env
sed -i "s/__USER__/${user}/g" /var/www/${domain}/.env
sed -i "s/__PASS__/${pass}/g" /var/www/${domain}/.env

echo "Updating environment variables apache configuration..."
sudo sed -i "s/__DOMAIN__/${domain}/g" /etc/apache2/sites-available/${domain}.conf
sudo sed -i "s/__CONTACT__/${contact}/g" /etc/apache2/sites-available/${domain}.conf

echo "Enabling domain ${domain} in Apache configuration..."
sudo a2ensite ${domain}

echo "Reloading Web server..."
sudo systemctl reload apache2

cd /var/www/${domain}

echo "Creating Default Folders.."
if [ -d /var/www/${domain}/public/upload ]
then
echo "upload folder exists."
else
sudo mkdir /var/www/${domain}/public/upload/import
fi
if [ -d /var/www/${domain}/public/upload/import ]
then
echo "import folder exists."
else
sudo mkdir /var/www/${domain}/public/upload/import
fi
if [ -d /var/www/${domain}/public/upload/export ]
then
echo "export folder exists."
else
sudo mkdir /var/www/${domain}/public/upload/export
fi
if [ -d /var/www/${domain}/public/temp ]
then
echo "temporary folder exists."
else
sudo mkdir /var/www/${domain}/public/upload/temp
fi
if [ -d /var/www/${domain}/public/upload/temp ]
then
echo "temporary folder exists."
else
sudo mkdir /var/www/${domain}/public/upload/temp
fi
if [ -d /var/www/${domain}/public/upload/library ]
then
echo "library folder exists."
else
sudo mkdir /var/www/${domain}/public/upload/library
fi
if [ -d /var/www/${domain}/public/upload/location ]
then
echo "location folder exists."
else
sudo mkdir /var/www/${domain}/public/upload/location
fi
if [ -d /var/www/${domain}/public/upload/srf ]
then
echo "srf folder exists."
else
sudo mkdir /var/www/${domain}/public/upload/srf
fi

echo 'Setting up directory permissions..'
sudo chown -R www-data:www-data /var/www/${domain}/
sudo chmod -R 765 /var/www/${domain}/
sudo chown -R www-data:www-data /var/www/${domain}/public/upload
sudo chmod -R 777 /var/www/${domain}/public/upload
sudo chown -R www-data:www-data /var/www/${domain}/vendor
sudo chown -R www-data:www-data /var/www/${domain}/storage
sudo setfacl -R -m u:$USER:rwx /var/www

echo 'Updating Composer..'

composer update

echo 'Migrating Database..'
if [ "$1" = "reset" ]
 then
    sudo mysql < ${SCRIPT_DIR}/data/db.sql
    php artisan migrate:refresh
    echo 'Generating Passport Auth Keys..'
    #php artisan passport:keys
    php artisan passport:install --force
    echo 'Running Initial Queries..'
    sudo mysql ${db} < /var/www/${domain}/database/sqls/seed.sql
else 
    php artisan migrate
    if [ "$1" = "" ]
    then
        echo 'Generating Passport Auth Keys..'
        php artisan passport:install
        echo 'Running Initial Queries..'
        sudo mysql ${db} < /var/www/${domain}/database/sqls/seed.sql
    fi
fi