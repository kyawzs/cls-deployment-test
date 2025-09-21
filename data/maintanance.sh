#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source ${SCRIPT_DIR}/../.env
cd /var/www/${domain}
echo "Enabling maintanance mode.."
php artisan down
echo "Cleaning directories.."
sudo rm -r /var/www/${domain}/public/temp/*
sudo rm -r /var/www/${domain}/public/upload/export/* 
echo "Disabling maintanance mode.."
sudo rm storage/framework/down
php artisan up

