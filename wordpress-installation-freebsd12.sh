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

printf "${GREEN}Done${NC}\n"
printf "Downloading WordPress and populating default config files: "

## Download and install wp-cli ##
cd /root/
if [[ ! -f /root/wp-cli.phar ]]; then
    curl -s https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar > wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi

printf "."

## Make Apache conf file sensible and ready for use with WordPress
cp /usr/local/etc/apache24/httpd.conf /usr/local/etc/apache24/httpd.conf.BACKUP
rm /usr/local/etc/apache24/httpd.conf

cat <<'EOF_APACHECONFIG' | cat > /usr/local/etc/apache24/httpd.conf
ServerRoot "/usr/local"
Listen 80
LoadModule mpm_prefork_module libexec/apache24/mod_mpm_prefork.so
LoadModule authn_file_module libexec/apache24/mod_authn_file.so
LoadModule authn_core_module libexec/apache24/mod_authn_core.so
LoadModule authz_host_module libexec/apache24/mod_authz_host.so
LoadModule authz_groupfile_module libexec/apache24/mod_authz_groupfile.so
LoadModule authz_user_module libexec/apache24/mod_authz_user.so
LoadModule authz_core_module libexec/apache24/mod_authz_core.so
LoadModule access_compat_module libexec/apache24/mod_access_compat.so
LoadModule auth_basic_module libexec/apache24/mod_auth_basic.so
LoadModule reqtimeout_module libexec/apache24/mod_reqtimeout.so
LoadModule filter_module libexec/apache24/mod_filter.so
LoadModule mime_module libexec/apache24/mod_mime.so
LoadModule log_config_module libexec/apache24/mod_log_config.so
LoadModule env_module libexec/apache24/mod_env.so
LoadModule headers_module libexec/apache24/mod_headers.so
LoadModule setenvif_module libexec/apache24/mod_setenvif.so
LoadModule version_module libexec/apache24/mod_version.so
LoadModule remoteip_module libexec/apache24/mod_remoteip.so
LoadModule ssl_module libexec/apache24/mod_ssl.so
LoadModule unixd_module libexec/apache24/mod_unixd.so
LoadModule status_module libexec/apache24/mod_status.so
LoadModule autoindex_module libexec/apache24/mod_autoindex.so
<IfModule !mpm_prefork_module>
	#LoadModule cgid_module libexec/apache24/mod_cgid.so
</IfModule>
<IfModule mpm_prefork_module>
	#LoadModule cgi_module libexec/apache24/mod_cgi.so
</IfModule>
LoadModule dir_module libexec/apache24/mod_dir.so
LoadModule alias_module libexec/apache24/mod_alias.so
LoadModule rewrite_module libexec/apache24/mod_rewrite.so
LoadModule php_module libexec/apache24/libphp.so

# Third party modules
IncludeOptional etc/apache24/modules.d/[0-9][0-9][0-9]_*.conf
 
<IfModule unixd_module>
User www
Group www
</IfModule>

ServerAdmin random@rdomain.intranet

<Directory />
    AllowOverride None
    Require all denied
</Directory>

DocumentRoot "/usr/local/www/apache24/data"
<Directory "/usr/local/www/apache24/data">
    Options -Indexes
    AllowOverride All
    Require all granted
</Directory>

<IfModule dir_module>
    DirectoryIndex index.php index.html
</IfModule>

<Files ".ht*">
    Require all denied
</Files>

ErrorLog "/var/log/httpd-error.log"

LogLevel warn

<IfModule log_config_module>
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %b" common

    <IfModule logio_module>
      LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %I %O" combinedio
    </IfModule>

    CustomLog "/var/log/httpd-access.log" common

</IfModule>

<IfModule alias_module>
    ScriptAlias /cgi-bin/ "/usr/local/www/apache24/cgi-bin/"
</IfModule>

<IfModule cgid_module>
</IfModule>

<Directory "/usr/local/www/apache24/cgi-bin">
    AllowOverride None
    Options None
    Require all granted
</Directory>

<IfModule headers_module>
    RequestHeader unset Proxy early
</IfModule>

<IfModule remoteip_module>
    RemoteIPHeader X-Forwarded-For
    RemoteIPInternalProxy 10.0.0.0/8
    RemoteIPInternalProxy 172.16.0.0/12
    RemoteIPInternalProxy 192.168.0.0/16
</IfModule>

<IfModule mime_module>
    TypesConfig etc/apache24/mime.types
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz
</IfModule>

<IfModule proxy_html_module>
Include etc/apache24/extra/proxy-html.conf
</IfModule>

<IfModule ssl_module>
SSLRandomSeed startup builtin
SSLRandomSeed connect builtin
</IfModule>

Include etc/apache24/Includes/*.conf
EOF_APACHECONFIG

## Restart apache and make sure that it's running ##
service apache24 restart &> /dev/null

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

## Initialize new WordPress website and remove the default content ##
sudo -u www wp core install --url=http://127.0.0.1 --title="Dragos Created Website" --admin_user=admin --admin_password=admin --admin_email=dragosonisei@gmail.com &> /dev/null
sudo -u www wp site empty --yes &> /dev/null

printf " .. ${GREEN}Done${NC}\n"

## Restart apache and ensure it's running ##
service apache24 restart &> /dev/null

IPADDR=$(ifconfig | grep "192\|10\|172" | awk '{print $2}' | awk '/^192|^10|^172/')

printf "The installation is now finished. In case you forgot, this VM IP is: ${GREEN}${IPADDR}${NC}\n"
printf "Go to ${GREEN}http://${IPADDR}/wp-admin/${NC} if you'd like to configure or test your new WordPress website.\n"

printf "\n"
