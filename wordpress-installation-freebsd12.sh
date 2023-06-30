#!/usr/local/bin/bash

printf "\n"

## Set the colors ##
NC='\033[0m'
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BROWN_ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'

if [[ $USER = root ]]; then
    printf "You ${GREEN}passed the root user check${NC}, all good.\n"
else
    printf "You are not root!!! Log in as root, please.\n"
    exit
fi

if [[ ${SHELL} = $(which bash) ]] || [[ ${SHELL} = /usr/local/bin/bash ]] || [[ ${SHELL} = /bin/bash ]]; then
	printf "bash is a sane choice of shell, ${GREEN}proceeding with the install${NC}.\n"

else
    printf "This is not bash! Installing and setting bash as your default shell, re-login and start the script again.\n"
    pkg install -y bash &> /dev/null
    chsh -s bash root
    exit
fi

printf "\n"
printf "Installing and configuring software: "

## Pre-Install the software required for basic jail stuff ##
pkg install -y nano &> /dev/null
pkg install -y mod_php80 php80-mysqli php80-tokenizer php80-zlib php80-zip php80 rsync php80-gd curl php80-curl php80-xml php80-bcmath php80-mbstring php80-pecl-imagick php80-pecl-imagick-im7 php80-iconv php80-filter php80-pecl-json_post php80-pear-Services_JSON php80-exif php80-fileinfo php80-dom php80-session php80-ctype php80-simplexml php80-phar php80-gmp &> /dev/null
pkg install -y apache24 mariadb106-server mariadb106-client
sysrc apache24_enable=yes mysql_enable=yes &> /dev/null
service apache24 start &> /dev/null


## Install the software required for basic jail stuff ##
pkg update -fq &> /dev/null
pkg upgrade -y &> /dev/null
pkg install -y nano htop bmon iftop pwgen sudo figlet &> /dev/null

printf "."

## Set the correct banner ##
figlet GATEWAY - IT > /etc/motd
service motd restart &> /dev/null

## Up to 30 JUN 2023 the newest version of working MariaDB of FreeBSD was 10.6, that's why it is used here. ##
pkg install -y apache24 mariadb106-server mariadb106-client &> /dev/null

printf "."

## Enable and start the services ##
sysrc apache24_enable=yes mysql_enable=yes &> /dev/null
service apache24 start &> /dev/null
service mysql-server start &> /dev/null

#### Create if check to perform health check on MariaDB server and Apache24 ####
#### Create if check to perform health check on MariaDB server and Apache24 ####
#### Create if check to perform health check on MariaDB server and Apache24 ####

## Create the symlink for the php config file ##
ln -s /usr/local/etc/php.ini-production /usr/local/etc/php.ini &> /dev/null

## Secure MariaDB installation ##
mysql_secure_installation

printf "\n"

## Set the MySQL root password ##
read -p "Enter the new MySQL root password: " mysql_root_password
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';" &> /dev/null

printf "\n"

## Install phpMyAdmin ##
pkg install -y phpMyAdmin &> /dev/null

## Configure phpMyAdmin ##
cp /usr/local/etc/php.ini /usr/local/etc/php.ini.bak &> /dev/null
sed -i '' 's/post_max_size = 8M/post_max_size = 32M/g' /usr/local/etc/php.ini
sed -i '' 's/upload_max_filesize = 2M/upload_max_filesize = 32M/g' /usr/local/etc/php.ini
sed -i '' 's/max_execution_time = 30/max_execution_time = 300/g' /usr/local/etc/php.ini
sed -i '' 's/max_input_time = 60/max_input_time = 300/g' /usr/local/etc/php.ini

printf "\n"

## Restart Apache24 for the changes to take effect ##
service apache24 restart &> /dev/null

## Create a symbolic link for phpMyAdmin ##
ln -s /usr/local/www/phpMyAdmin/ /usr/local/www/html/phpMyAdmin &> /dev/null

## Set permissions for the phpMyAdmin folder ##
chmod -R 0750 /usr/local/www/phpMyAdmin &> /dev/null
chown -R www:www /usr/local/www/phpMyAdmin &> /dev/null

printf "\n"

## Install and configure WordPress ##
pkg install -y wordpress-php80 &> /dev/null

## Copy the WordPress sample configuration file to the actual configuration file ##
cp /usr/local/etc/wordpress/wp-config-sample.php /usr/local/etc/wordpress/wp-config.php &> /dev/null

## Generate random keys and salts ##
keys=("AUTH_KEY" "SECURE_AUTH_KEY" "LOGGED_IN_KEY" "NONCE_KEY" "AUTH_SALT" "SECURE_AUTH_SALT" "LOGGED_IN_SALT" "NONCE_SALT")

for key in "${keys[@]}"; do
    sed -i '' "s/define('${key}',.*/define('${key}', '$(pwgen -s 64 1)');/g" /usr/local/etc/wordpress/wp-config.php
done

printf "\n"

## Set the MySQL credentials in the WordPress configuration file ##
read -p "Enter the MySQL username for WordPress: " mysql_username
read -sp "Enter the MySQL password for WordPress: " mysql_password
printf "\n"
sed -i '' "s/define('DB_USER', .*/define('DB_USER', '${mysql_username}');/g" /usr/local/etc/wordpress/wp-config.php
sed -i '' "s/define('DB_PASSWORD', .*/define('DB_PASSWORD', '${mysql_password}');/g" /usr/local/etc/wordpress/wp-config.php

printf "\n"

## Set the WordPress table prefix ##
read -p "Enter a table prefix for WordPress (e.g., wp_): " table_prefix
sed -i '' "s/\$table_prefix  = 'wp_';/\$table_prefix  = '${table_prefix}';/g" /usr/local/etc/wordpress/wp-config.php

printf "\n"

## Restart Apache24 for the changes to take effect ##
service apache24 restart &> /dev/null

printf "\n"

## Display the installation details ##
printf "${GREEN}Installation completed!${NC}\n"
printf "\n"
printf "WordPress installation details:\n"
printf "===============================\n"
printf "URL: http://your_domain.com/\n"
printf "MySQL Database: localhost\n"
printf "MySQL Username: ${mysql_username}\n"
printf "MySQL Password: ${mysql_password}\n"
printf "Table Prefix: ${table_prefix}\n"
printf "===============================\n"
printf "\n"
