#!/bin/bash
#�ж�ϵͳ
if [ ! -e '/etc/redhat-release' ]; then
echo "��֧��centos7"
exit
fi
if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
echo "��֧��centos7"
exit
fi
CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
if [ "$CHECK" == "SELINUX=enforcing" ]; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
if [ "$CHECK" == "SELINUX=permissive" ]; then
    sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
function blue(){
    echo -e "\033[34m\033[01m $1 \033[0m"
}
function green(){
    echo -e "\033[32m\033[01m $1 \033[0m"
}
function red(){
    echo -e "\033[31m\033[01m $1 \033[0m"
}
function yellow(){
    echo -e "\033[33m\033[01m $1 \033[0m"
}


#��װnginx
install_nginx(){
    systemctl stop firewalld
    systemctl disable firewalld
    yum install -y libtool perl-core zlib-devel gcc wget pcre* unzip
    wget https://www.openssl.org/source/old/1.1.1/openssl-1.1.1a.tar.gz
    tar xzvf openssl-1.1.1a.tar.gz
    
    mkdir /etc/nginx
    mkdir /etc/nginx/ssl
    mkdir /etc/nginx/conf.d
    wget https://nginx.org/download/nginx-1.15.8.tar.gz
    tar xf nginx-1.15.8.tar.gz && rm nginx-1.15.8.tar.gz
    cd nginx-1.15.8
    ./configure --prefix=/etc/nginx --with-openssl=../openssl-1.1.1a --with-openssl-opt='enable-tls1_3' --with-http_v2_module --with-http_ssl_module --with-http_gzip_static_module --with-http_stub_status_module --with-http_sub_module --with-stream --with-stream_ssl_module
    make && make install
    
    green "======================"
    green " �����������VPS������"
    green "======================"
    read domain
    
cat > /etc/nginx/conf/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /etc/nginx/logs/error.log warn;
pid        /etc/nginx/logs/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/conf/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /etc/nginx/logs/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    include /etc/nginx/conf.d/*.conf;
}
EOF

cat > /etc/nginx/conf.d/default.conf<<-EOF
server {
    listen       80;
    server_name  $domain;
    root /etc/nginx/html;
    index index.php index.html index.htm;
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /etc/nginx/html;
    }
}
EOF

    /etc/nginx/sbin/nginx

    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh  --issue  -d $domain  --webroot /etc/nginx/html/
    ~/.acme.sh/acme.sh  --installcert  -d  $domain   \
        --key-file   /etc/nginx/ssl/$domain.key \
        --fullchain-file /etc/nginx/ssl/fullchain.cer \
        --reloadcmd  "/etc/nginx/sbin/nginx -s reload"
	
cat > /etc/nginx/conf.d/default.conf<<-EOF
server { 
    listen       80;
    server_name  $domain;
    rewrite ^(.*)$  https://\$host\$1 permanent; 
}
server {
    listen 443 ssl http2;
    server_name $domain;
    root /etc/nginx/html;
    index index.php index.html;
    ssl_certificate /etc/nginx/ssl/fullchain.cer; 
    ssl_certificate_key /etc/nginx/ssl/$domain.key;
    #TLS �汾����
    ssl_protocols   TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_ciphers     'TLS13-AES-256-GCM-SHA384:TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-128-GCM-SHA256:TLS13-AES-128-CCM-8-SHA256:TLS13-AES-128-CCM-SHA256:EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5';
    ssl_prefer_server_ciphers   on;
    # ���� 1.3 0-RTT
    ssl_early_data  on;
    ssl_stapling on;
    ssl_stapling_verify on;
    #add_header Strict-Transport-Security "max-age=31536000";
    #access_log /var/log/nginx/access.log combined;
    location /mypath {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:11234; 
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location / {
       try_files \$uri \$uri/ /index.php?\$args;
    }
}
EOF
}
#��װv2ray
install_v2ray(){
    
    yum install -y wget
    bash <(curl -L -s https://install.direct/go.sh)  
    cd /etc/v2ray/
    rm -f config.json
    wget https://raw.githubusercontent.com/atrandys/v2ray-ws-tls/master/config.json
    v2uuid=$(cat /proc/sys/kernel/random/uuid)
    sed -i "s/aaaa/$v2uuid/;" config.json
    newpath=$(cat /dev/urandom | head -1 | md5sum | head -c 4)
    sed -i "s/mypath/$newpath/;" config.json
    sed -i "s/mypath/$newpath/;" /etc/nginx/conf.d/default.conf
    cd /etc/nginx/html
    rm -f /etc/nginx/html/*
    wget https://github.com/atrandys/v2ray-ws-tls/raw/master/web.zip
    unzip web.zip
    /etc/nginx/sbin/nginx -s stop
    /etc/nginx/sbin/nginx
    systemctl restart v2ray.service
    
    #�����������ű�
cat > /etc/rc.d/init.d/autov2ray<<-EOF
#!/bin/sh
#chkconfig: 2345 80 90
#description:autov2ray
/etc/nginx/sbin/nginx
EOF

    #���ýű�Ȩ��
    chmod +x /etc/rc.d/init.d/autov2ray
    chkconfig --add autov2ray
    chkconfig autov2ray on

cat > /etc/v2ray/myconfig.json<<-EOF
{
===========���ò���=============
��ַ��${domain}
�˿ڣ�443
uuid��${v2uuid}
����id��64
���ܷ�ʽ��aes-128-gcm
����Э�飺ws
������myws
·����${newpath}
�ײ㴫�䣺tls
}
EOF

clear
green
green "��װ�Ѿ����"
green 
green "===========���ò���============"
green "��ַ��${domain}"
green "�˿ڣ�443"
green "uuid��${v2uuid}"
green "����id��64"
green "���ܷ�ʽ��aes-128-gcm"
green "����Э�飺ws"
green "������myws"
green "·����${newpath}"
green "�ײ㴫�䣺tls"
green 
}

remove_v2ray(){

    /etc/nginx/sbin/nginx -s stop
    systemctl stop v2ray.service
    systemctl disable v2ray.service
    
    rm -rf /usr/bin/v2ray /etc/v2ray
    rm -rf /etc/v2ray
    rm -rf /etc/nginx
    
    green "nginx��v2ray��ɾ��"
    
}

start_menu(){
    clear
    green " ===================================="
    green " ���ܣ�һ����װv2ray+ws+tls           "
    green " ϵͳ��centos7                       "
    green " ���ߣ�A                      "
    green " ===================================="
    echo
    green " 1. ��װv2ray+ws+tls"
    green " 2. ����v2ray"
    red " 3. ж��v2ray"
    yellow " 0. �˳��ű�"
    echo
    read -p "����������:" num
    case "$num" in
    1)
    install_nginx
    install_v2ray
    ;;
    2)
    bash <(curl -L -s https://install.direct/go.sh)  
    ;;
    3)
    remove_v2ray 
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "��������ȷ����"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu


