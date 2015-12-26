#!/bin/sh
#########################################################################
# File Name: start.sh
# Author: Skiychan
# Email:  dev@skiy.net
# Version:
# Created Time: 2015/12/13
#########################################################################
Nginx_Install_Dir=/usr/local/nginx
DATA_DIR=/data/www

set -e

chown -R www.www $DATA_DIR

if [[ -n "$PROXY_WEB" ]]; then

    [ -f "${Nginx_Install_Dir}/conf/ssl" ] || mkdir -p $Nginx_Install_Dir/conf/ssl
    [ -f "${Nginx_Install_Dir}/conf/vhost" ] || mkdir -p $Nginx_Install_Dir/conf/vhost
    ln -s  $Nginx_Install_Dir/conf/ssl /data/nginx/conf/ssl 
    ln -s  $Nginx_Install_Dir/conf/vhost /data/nginx/conf/vhost
    if [ -z "$PROXY_DOMAIN" ]; then
            echo >&2 'error:  missing PROXY_DOMAIN'
            echo >&2 '  Did you forget to add -e PROXY_DOMAIN=... ?'
            exit 1
    fi

    if [ -z "$PROXY_CRT" ]; then
         echo >&2 'error:  missing PROXY_CRT'
         echo >&2 '  Did you forget to add -e PROXY_CRT=... ?'
         exit 1
     fi

     if [ -z "$PROXY_KEY" ]; then
             echo >&2 'error:  missing PROXY_KEY'
             echo >&2 '  Did you forget to add -e PROXY_KEY=... ?'
             exit 1
     fi

     if [ ! -f "${Nginx_Install_Dir}/conf/ssl/${PROXY_CRT}" ]; then
             echo >&2 'error:  missing PROXY_CRT'
             echo >&2 "  You need to put ${PROXY_CRT} in ssl directory"
             exit 1
     fi

     if [ ! -f "${Nginx_Install_Dir}/conf/ssl/${PROXY_KEY}" ]; then
             echo >&2 'error:  missing PROXY_CSR'
             echo >&2 "  You need to put ${PROXY_KEY} in ssl directory"
             exit 1
     fi

    cat > ${Nginx_Install_Dir}/conf/vhost/website.conf << EOF
server {
    listen 80;
    server_name $PROXY_DOMAIN;
    return 301 https://$PROXY_DOMAIN\$request_uri;
    }

server {
    listen 443 ssl;
    server_name $PROXY_DOMAIN;

    ssl on;
    ssl_certificate ssl/${PROXY_CRT};
    ssl_certificate_key ssl/${PROXY_KEY};
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ALL:!aNULL:!ADH:!eNULL:!LOW:!EXP:RC4+RSA:+HIGH:+MEDIUM;
    keepalive_timeout 70;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    root   $DATA_DIR;
    index  index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        root           /data/www;
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  /\$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }
}
EOF
fi
VOLUME_HOME="/data/mysql"

if [[ ! -d $VOLUME_HOME/mysql ]]; then
    echo "=> An empty or uninitialized MariaDB volume is detected in $VOLUME_HOME"
    echo "=> Installing MariaDB ..."
    mysql_install_db > /dev/null 2>&1
    echo "=> Done!"  
    /create_mariadb_admin_user.sh
else
    echo "=> Using an existing volume of MariaDB"
fi

exec mysqld_safe
/usr/bin/supervisord -n -c /etc/supervisord.conf
