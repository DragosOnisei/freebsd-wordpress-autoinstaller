#!/usr/local/bin/bash

# Set the colors
NC='\033[0m'
GREEN='\033[0;32m'

printf "\n"

if [[ $USER != root ]]; then
    printf "You are not root!!! Log in as root, please.\n"
    exit
fi

if [[ ${SHELL} != $(which bash) ]] && [[ ${SHELL} != /usr/local/bin/bash ]] && [[ ${SHELL} != /bin/bash ]]; then
    printf "This is not bash! Installing and setting bash as your default shell, re-login and start the script again.\n"
    pkg install -y bash &> /dev/null
    chsh -s bash root
    exit
fi

printf "Installing and configuring software:... "

# Pre-Install the software required for basic jail setup
pkg install -y nano &> /dev/null
pkg install -y rsync curl pwgen
pkg install -y mod_php80

# Install MariaDB 10.5
pkg install -y mariadb105-server mariadb105-client

# Enable and start MariaDB on boot
sysrc mysql_enable="YES"
service mysql-server start

# Secure the MariaDB installation
mysql_secure_installation <<EOF_MYSQL_SECURE
n
y
y
y
y
EOF_MYSQL_SECURE

# Install Apache
pkg install -y apache24

# Enable and start Apache on boot
sysrc apache24_enable="YES"
service apache24 start

# Install required PHP extensions
pkg install -y php80-mysqli php80-tokenizer php80-zlib php80-zip php80-gd php80-curl php80-xml php80-bcmath php80-mbstring php80-pecl-imagick php80-pecl-imagick-im7 php80-iconv php80-filter php80-pecl-json_post php80-pear-Services_JSON php80-exif php80-fileinfo php80-dom php80-session php80-ctype php80-simplexml php80-phar php80-gmp

printf "${GREEN}Done${NC}\n"
printf "Configuring Apache:..."

# Update the Apache configuration file
sed -i '' -e 's/#LoadModule php_module libexec\/apache24\/libphp.so/LoadModule php_module libexec\/apache24\/libphp.so/' /usr/local/etc/apache24/httpd.conf

# Add PHP file handling to Apache configuration
cat <<EOF_APACHE_PHP >> /usr/local/etc/apache24/httpd.conf

<IfModule dir_module>
    DirectoryIndex index.php index.html
    <FilesMatch "\.php$">
        SetHandler application/x-httpd-php
    </FilesMatch>
    <FilesMatch "\.phps$">
        SetHandler application/x-httpd-php-source
    </FilesMatch>
</IfModule>
EOF_APACHE_PHP

# Restart Apache
service apache24 restart

printf "${GREEN}Done${NC}\n"
printf "Downloading WordPress and setting up configuration:..."

# Download and install WP-CLI
cd /root/
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar &> /dev/null
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Install WordPress
cd /usr/local/www/
wp core download --allow-root
wp config create --dbname='wordpress' --dbuser='wpuser' --dbpass='wppassword' --allow-root
wp core install --url='http://localhost' --title='My WordPress Site' --admin_user='admin' --admin_password='admin' --admin_email='admin@example.com' --allow-root

# Set file permissions
chown -R www:www /usr/local/www/

printf "${GREEN}Done${NC}\n"

printf "\n"
printf "The installation is now finished. You can access your WordPress site by visiting ${GREEN}http://localhost${NC} in your web browser.\n"
printf "You can log in to the WordPress admin dashboard with the username ${GREEN}admin${NC} and the password ${GREEN}admin${NC}.\n"
printf "\n"
