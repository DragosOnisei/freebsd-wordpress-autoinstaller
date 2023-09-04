#!/usr/local/bin/bash

printf "\n"

## Set the colors ##
NC='\033[0m'
GREEN='\033[0;32m'

if [[ $USER != root ]]; then
    printf "You are not root!!! Log in as root, please.\n"
    exit
fi

printf "Installing and configuring software:... \n"

## Pre-Install the software required for basic jail stuff ##
pkg install -y nano &> /dev/null
pkg install -y mod_php80 php80-mysqli php80-tokenizer php80-zlib php80-zip php80 rsync php80-gd curl php80-curl php80-xml php80-bcmath php80-mbstring php80-pecl-imagick php80-pecl-imagick-im7 php80-iconv php80-filter php80-pecl-json_post php80-pear-Services_JSON php80-exif php80-fileinfo php80-dom php80-session php80-ctype php80-simplexml php80-phar php80-gmp &> /dev/null
pkg install -y apache24 mariadb104-server mariadb104-client

sysrc apache24_enable=yes mysql_enable=yes &> /dev/null
service apache24 start &> /dev/null
service mysql-server start &> /dev/null

pkg update -fq &> /dev/null
pkg upgrade -y &> /dev/null
pkg install -y nano htop bmon iftop pwgen sudo figlet &> /dev/null

printf "."

## Set the correct banner ##
figlet GATEWAY - IT > /etc/motd
service motd restart &> /dev/null

## Secure the MariaDB install ##
mysql_secure_installation <<EOF_MSQLSI &> /dev/null

n
y
y
y
y
EOF_MSQLSI

printf "."

## Download the latest version of WordPress and move it into the correct folder with the right permissions ##
cd /tmp

if [[ ! -f /tmp/latest.tar.gz ]]; then
    curl -s https://wordpress.org/latest.tar.gz -o latest.tar.gz -Y 10000 -y 10
fi

tar xf /tmp/latest.tar.gz

printf "."

rm /usr/local/www/apache24/data/index.html

cp -r /tmp/wordpress/* /usr/local/www/apache24/data/
chown -R www:www /usr/local/www/apache24/data/

## .htaccess file + some php.ini configuration settings inside it ##
touch /usr/local/www/apache24/data/.htaccess &> /dev/null
chown www:www /usr/local/www/apache24/data/.htaccess

echo "#PHP.INI VALUES" >> /usr/local/www/apache24/data/.htaccess
echo "php_value upload_max_filesize 500M" >> /usr/local/www/apache24/data/.htaccess
echo "php_value post_max_size 500M" >> /usr/local/www/apache24/data/.htaccess
echo "php_value memory_limit 256M" >> /usr/local/www/apache24/data/.htaccess
echo "php_value max_execution_time 300" >> /usr/local/www/apache24/data/.htaccess
echo "php_value max_input_time 300" >> /usr/local/www/apache24/data/.htaccess

printf "."

## Create a custom wp-config.php file with the correct database and salts configuration ##
WP_DB_PREFIX="wp_$(pwgen 10 1 --no-capitalize --no-numerals)"
WP_SALT1="$(pwgen 64 1)"
WP_SALT2="$(pwgen 64 1)"
WP_SALT3="$(pwgen 64 1)"
WP_SALT4="$(pwgen 64 1)"
WP_SALT5="$(pwgen 64 1)"
WP_SALT6="$(pwgen 64 1)"
WP_SALT7="$(pwgen 64 1)"
WP_SALT8="$(pwgen 64 1)"

cp /usr/local/www/apache24/data/wp-config-sample.php /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'DB_NAME'/s/'[^']*'/'your_database_name_here'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'DB_USER'/s/'[^']*'/'your_username_here'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'DB_PASSWORD'/s/'[^']*'/'your_password_here'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'DB_HOST'/s/'[^']*'/'localhost'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/table_prefix/p" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/table_prefix/s/wp_/${WP_DB_PREFIX}/g" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'AUTH_KEY',/s/'[^']*'/'${WP_SALT1}'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'SECURE_AUTH_KEY',/s/'[^']*'/'${WP_SALT2}'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'LOGGED_IN_KEY',/s/'[^']*'/'${WP_SALT3}'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'NONCE_KEY',/s/'[^']*'/'${WP_SALT4}'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'AUTH_SALT',/s/'[^']*'/'${WP_SALT5}'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'SECURE_AUTH_SALT',/s/'[^']*'/'${WP_SALT6}'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'LOGGED_IN_SALT',/s/'[^']*'/'${WP_SALT7}'/" /usr/local/www/apache24/data/wp-config.php
sed -i '' "/define( 'NONCE_SALT',/s/'[^']*'/'${WP_SALT8}'/" /usr/local/www/apache24/data/wp-config.php

printf "."

## Restart apache and ensure it's running ##
service apache24 restart &> /dev/null

IPADDR=$(ifconfig | grep "192\|10\|172" | awk '{print $2}' | awk '/^192|^10|^172/')

printf "The installation is now finished. In case you forgot, this VM IP is: ${GREEN}${IPADDR}${NC}\n"
printf "Go to ${GREEN}http://${IPADDR}/wp-admin/${NC} if you'd like to configure or test your new WordPress website.\n"

printf "\n"
