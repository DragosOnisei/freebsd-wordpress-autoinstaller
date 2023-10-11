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

if [[ ${SHELL} != $(which bash) ]] || [[ ${SHELL} != /usr/local/bin/bash ]] || [[ ${SHELL} != /bin/bash ]]; then
    printf "This is not bash! Installing and setting bash as your default shell, re-login and start the script again.\n"
    pkg install -y bash &> /dev/null
    chsh -s bash root
    exit
fi

printf "\n"
printf "Installing and configuring software:... "

## Pre-Install the software required for basic jail stuff ##
pkg install -y nano &> /dev/null
pkg install -y mod_php80 php80-mysqli php80-tokenizer php80-zlib php80-zip php80 rsync php80-gd curl php80-curl php80-xml php80-bcmath php80-mbstring php80-pecl-imagick php80-pecl-imagick-im7 php80-iconv php80-filter php80-pecl-json_post php80-pear-Services_JSON php80-exif php80-fileinfo php80-dom php80-session php80-ctype php80-simplexml php80-phar php80-gmp &> /dev/null
pkg install -y apache24 mariadb106-server mariadb106-client &> /dev/null

# Enable and start Apache and MariaDB
sysrc apache24_enable=yes mysql_enable=yes &> /dev/null
service apache24 start &> /dev/null
service mysql-server start &> /dev/null

printf "${GREEN}Done${NC}\n"
printf "Downloading WordPress, WP-CLI, and populating default config files: "

## Download and install wp-cli ##
cd /root/
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar &> /dev/null
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

## Download the latest version of WordPress ##
cd /usr/local/www/apache24/data/
if [[ ! -f latest.tar.gz ]]; then
    curl -s https://wordpress.org/latest.tar.gz -o latest.tar.gz
    tar xf latest.tar.gz --strip-components=1
    rm latest.tar.gz
fi

printf "${GREEN}Done${NC}\n"
printf "Initializing the WordPress installation and removing the default trash: "

## Create wp-config.php ##
# Generate unique salts for wp-config.php
WP_SALTS=$(wp core secret-key)

# Generate database and user credentials
DB_ROOT_PASSWORD=$(pwgen $(( RANDOM%7+8 )) 1)
DB_WPDB_NAME="wpdb_$(pwgen $(( RANDOM%2+3 )) 1 --no-numerals --no-capitalize)"
DB_WPDB_USER="wpdbuser_$(pwgen $(( RANDOM%2+3 )) 1 --no-numerals --no-capitalize)"
DB_WPDB_USER_PASSWORD=$(pwgen $(( RANDOM%7+8 )) 1)

wp core config --dbname=$DB_WPDB_NAME --dbuser=$DB_WPDB_USER --dbpass=$DB_WPDB_USER_PASSWORD --dbhost=localhost --dbcharset=utf8 --extra-php <<PHP
define( 'WP_DEBUG', false );
\$table_prefix = 'wp_';

${WP_SALTS}
PHP

chown -R www:www /usr/local/www/apache24/data/

## Install WordPress ##
wp core install --url=http://localhost --title="My Website" --admin_user=admin --admin_password=admin --admin_email=admin@example.com

## Clean up ##
wp post delete 1 --force # Delete default 'Hello World!' post
wp plugin delete hello akismet --allow-root # Delete default plugins

printf "${GREEN}Done${NC}\n"

# Code to print installation summary

IP=$(ifconfig | awk '/inet /{print $2}' | grep -E '^192|^10|^172' | head -n 1)

printf "\n"
printf "WordPress installation completed.\n"
printf "Website URL: ${CYAN}http://${IP}/wp-admin/${NC}\n"
printf "Admin username: ${CYAN}admin${NC}\n"
printf "Admin password: ${CYAN}admin${NC}\n"
printf "MySQL/MariaDB root password: ${CYAN}${DB_ROOT_PASSWORD}${NC}\n"
printf "WordPress DB name: ${CYAN}${DB_WPDB_NAME}${NC}\n"
printf "WordPress DB username: ${CYAN}${DB_WPDB_USER}${NC}\n"
printf "WordPress DB user password: ${CYAN}${DB_WPDB_USER_PASSWORD}${NC}\n"
printf "\n"
