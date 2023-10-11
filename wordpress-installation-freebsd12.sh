#!/usr/local/bin/bash

# Set the colors
NC='\033[0m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'

# Check if the script is executed as root
if [[ $EUID -ne 0 ]]; then
    printf "You must be root to run this script.\n"
    exit 1
fi

# Check if bash is the default shell
if [[ ${SHELL} != $(which bash) ]]; then
    printf "Bash is not the default shell. Changing the default shell to bash...\n"
    chsh -s $(which bash) root
    printf "Please re-login and run the script again.\n"
    exit 1
fi

printf "Installing and configuring software...\n"

# Install required packages
pkg install -y nano mod_php80 php80-mysqli php80-tokenizer php80-zlib php80-zip php80 rsync php80-gd curl php80-curl php80-xml php80-bcmath php80-mbstring php80-pecl-imagick php80-pecl-imagick-im7 php80-iconv php80-filter php80-pecl-json_post php80-pear-Services_JSON php80-exif php80-fileinfo php80-dom php80-session php80-ctype php80-simplexml php80-phar php80-gmp apache24 mariadb106-server mariadb106-client &> /dev/null

# Enable and start Apache
sysrc apache24_enable=yes mysql_enable=yes &> /dev/null
service apache24 start &> /dev/null

# Secure the MariaDB install
mysql_secure_installation <<EOF_MYSQL_SECURE
n
y
y
y
y
EOF_MYSQL_SECURE

# Generate database and user credentials
DB_ROOT_PASSWORD=$(pwgen $(jot -r 1 43 51) 1)
DB_WPDB_NAME=wpdb_$(pwgen $(jot -r 1 3 5) 1 --no-numerals --no-capitalize)
DB_WPDB_USER=wpdbuser_$(pwgen $(jot -r 1 4 6) 1 --no-numerals --no-capitalize)
DB_WPDB_USER_PASSWORD=$(pwgen $(jot -r 1 43 53) 1)

# Set database root password
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"

# Create WordPress database and assign a new user to it
mysql -e "CREATE DATABASE ${DB_WPDB_NAME}; CREATE USER '${DB_WPDB_USER}'@localhost IDENTIFIED BY '${DB_WPDB_USER_PASSWORD}'; GRANT ALL PRIVILEGES ON ${DB_WPDB_NAME}.* TO ${DB_WPDB_USER}@'localhost'; FLUSH PRIVILEGES;"

# Download and install WordPress
if [[ ! -f /tmp/latest.tar.gz ]]; then
    curl -s https://wordpress.org/latest.tar.gz -o /tmp/latest.tar.gz -Y 10000 -y 10
fi

tar xf /tmp/latest.tar.gz -C /usr/local/www/apache24/data --strip-components=1
chown -R www:www /usr/local/www/apache24/data

# Generate unique salts for wp-config.php
WP_SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

# Create wp-config.php from template
cat <<EOF > /usr/local/www/apache24/data/wp-config.php
<?php
define( 'DB_NAME', '${DB_WPDB_NAME}' );
define( 'DB_USER', '${DB_WPDB_USER}' );
define( 'DB_PASSWORD', '${DB_WPDB_USER_PASSWORD}' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
${WP_SALTS}
\$table_prefix = 'wp_';
define( 'WP_DEBUG', false );
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}
require_once( ABSPATH . 'wp-settings.php' );
EOF

chown www:www /usr/local/www/apache24/data/wp-config.php

# Restart Apache
service apache24 restart &> /dev/null

# Get server IP address
IP_ADDRESS=$(ifconfig | awk '/inet /{print $2}' | grep -E '^192|^10|^172' | head -n 1)

# Print installation summary
printf "\n"
printf "WordPress installation completed.\n"
printf "Website URL: ${CYAN}http://${IP_ADDRESS}/wp-admin/${NC}\n"
printf "Admin username: ${CYAN}admin${NC}\n"
printf "Admin password: ${CYAN}admin${NC}\n"
printf "MySQL/MariaDB root password: ${CYAN}${DB_ROOT_PASSWORD}${NC}\n"
printf "WordPress DB name: ${CYAN}${DB_WPDB_NAME}${NC}\n"
printf "WordPress DB username: ${CYAN}${DB_WPDB_USER}${NC}\n"
printf "WordPress DB user password: ${CYAN}${DB_WPDB_USER_PASSWORD}${NC}\n"
printf "\n"
