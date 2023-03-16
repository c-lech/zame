#!/usr/bin/env bash
#
# ZAWE : Zabbix Awesome Monitoring Environment
#
# Vagrantfile/Scripting to deploy a complete ready to use Zabbix Awesome Monitoring Environment:
#
# -> CentOS Linux release 8.3.2011
# -> Zabbix 6 LTS + ( zabbix-java-gateway zabbix-get zabbix-sender zabbix-js )
# -> MySQL || PostgreSQL 14 + TimescaleDB2
# -> Apache || Nginx
# -> Grafana + alexanderzobnin-zabbix-datasource plugin
# -> Prometheus
# -> jq git python java perl nodejs pyzabbix zabbix-cli
# -> nc wget telnet net-tools net-snmp-utils
#

#
#      -> Arguments && Parameters
#

#
# Vagrantfile arguments -> provisioning script
#
# zabbix.vm.provision "shell", path: "bootstrap.sh", args: "nginx pgsql"  
#                                                           ----- -----

# apache || nginx

ZABBIX_WEB_SERVER=$1

# mysql || pgsql

ZABBIX_DB_SERVER=$2

# To break down nginx/nginx | apache/httpd 

case $ZABBIX_WEB_SERVER in

"nginx")

  ZABBIX_WEB_SERVER_service="$ZABBIX_WEB_SERVER"
  ZABBIX_URL="http://127.0.0.1:8080"

  ;;

"apache")

  ZABBIX_WEB_SERVER_service="httpd"
  ZABBIX_URL="http://127.0.0.1/zabbix"

  ;;

esac

ZABBIX_WEB_SERVER_package="$ZABBIX_WEB_SERVER"

# Speed up for testing purposes!!! -> Environment customization!

INSTALL_GRAFANA=true
INSTALL_PROMETHEUS=true
INSTALL_BONUS=true

# Timezone

TIMEZONE="America/Argentina/Buenos_Aires"

# Color is good!

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"

# No Color is good too!

NC="\033[0m"

#
# Write to output functions
#

out()

{

local -n COLOR="$2"

s="# "

for i in $(seq $3)
  do s+="   ";
done

[ $3 -ge 0 ] && s+="-> "

[ -z "$4" ] && f="#" || f=$4

echo -e "$COLOR\n$f\n$s$1\n$f$NC"

}

#
#      -> Start whith the Zabbix Awesome Monitoring Environment deployment!  
#

out "Start with the Zabbix Awesome Monitoring Environment deployment!" GREEN 0 "#\n#"

# To avoid some /home/vagrant messages on output.

cd /tmp

# Disable Firewalld and SElinux.

out "Disabling Firewalld and SElinux" RED 1

sudo setenforce 0 && sudo sed -i 's|SELINUX=enforcing|SELINUX=disabled|g' /etc/selinux/config 
sudo systemctl disable --now firewalld

# CentOS-* repos.

sudo sed -i "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-*
sudo sed -i "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-*

# Install packages ( wget needed! ) 

out "Installing nc wget telnet net-tools netnmp-utils" GREEN 1

sudo dnf install -y nc wget telnet net-tools net-snmp-utils

#
#      -> Install and configure Zabbix
#

out "Install and configure Zabbix" GREEN 0 "#\n#"

# Install

out "Installing zabbix-server-$ZABBIX_DB_SERVER zabbix-web-$ZABBIX_DB_SERVER zabbix-${ZABBIX_WEB_SERVER_package}-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent" GREEN 1

sudo rpm -Uvh https://repo.zabbix.com/zabbix/6.0/rhel/8/x86_64/zabbix-release-6.0-4.el8.noarch.rpm
sudo dnf clean all
sudo dnf install -y zabbix-server-$ZABBIX_DB_SERVER zabbix-web-$ZABBIX_DB_SERVER zabbix-${ZABBIX_WEB_SERVER_package}-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent

out "Installing zabbix-java-gateway zabbix-get zabbix-sender zabbix-js" GREEN 1

sudo dnf install -y zabbix-java-gateway zabbix-get zabbix-sender zabbix-js 

# Configure Zabbix

out "Configuring Zabbix" YELLOW 1

sudo sed -i 's|# DBHost=localhost|DBHost=localhost|g' /etc/zabbix/zabbix_server.conf
sudo sed -i 's|# DBPassword=|DBPassword=password|g' /etc/zabbix/zabbix_server.conf

sudo sed -i 's|# JavaGateway=|JavaGateway=127.0.0.1|g' /etc/zabbix/zabbix_server.conf
sudo sed -i 's|# JavaGatewayPort=10052|JavaGatewayPort=10052|g' /etc/zabbix/zabbix_server.conf
sudo sed -i 's|# StartJavaPollers=0|StartJavaPollers=2|g' /etc/zabbix/zabbix_server.conf

# Configure PHP

out "Configuring PHP" YELLOW 1

sudo echo "php_value[date.timezone] = $TIMEZONE" >> /etc/php-fpm.d/zabbix.conf

# Configure Nginx

if [ $ZABBIX_WEB_SERVER == "nginx" ]

then

  out "Configuring Nginx" YELLOW 1

  sudo sed -i 's|#        listen          8080;|        listen          8080;|g' /etc/nginx/conf.d/zabbix.conf
  sudo sed -i 's|#        server_name     example.com;|        server_name     _;|g' /etc/nginx/conf.d/zabbix.conf

fi

#
#      -> Install, configure and start DB 
#

out "Install, configure and start DB" GREEN 0 "#\n#"

case $ZABBIX_DB_SERVER in

"pgsql")

  # Install PostgreSQL 

  out "Installing PostgreSQL" GREEN 1

  sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
  sudo dnf -qy module disable postgresql 
  sudo dnf install -y postgresql14-server 
  sudo /usr/pgsql-14/bin/postgresql-14-setup initdb 

  # Configure PostgreSQL

  out "Configuring PostgreSQL" YELLOW 1

  sudo sed -i 's|^max_connections =.*|max_connections = 150|' /var/lib/pgsql/14/data/postgresql.conf

  # Start PostgreSQL 

  out "Starting PostgreSQL" GREEN 1

  sudo systemctl enable --now postgresql-14

  # Create zabbix user/DB 

  out "Creating zabbix user / DB ..." GREEN 1

  sudo -u postgres psql -c "CREATE USER zabbix WITH ENCRYPTED PASSWORD 'password'" 2>/dev/null
  sudo -u postgres createdb -O zabbix -E Unicode -T template0 zabbix 2>/dev/null
  sudo zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix PGPASSWORD=password psql -hlocalhost -Uzabbix zabbix 2>/dev/null

  # Install timescaledb2 extension

  out "Installing TimescaleDB2 extension" GREEN 1

  sudo tee /etc/yum.repos.d/timescale_timescaledb.repo <<EOL
[timescale_timescaledb]
name=timescale_timescaledb
baseurl=https://packagecloud.io/timescale/timescaledb/el/$(rpm -E %{rhel})/\$basearch
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://packagecloud.io/timescale/timescaledb/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOL

  sudo dnf install -y timescaledb-2-postgresql-14-2.8.1-0.el8.x86_64
  sudo timescaledb-tune --pg-config=/usr/pgsql-14/bin/pg_config -yes

  out "Restarting PostgreSQL" GREEN 1

  sudo systemctl restart postgresql-14

  sudo echo "CREATE EXTENSION IF NOT EXISTS timescaledb WITH VERSION '2.8.1' CASCADE;" | sudo -u postgres psql zabbix
  sudo cat /usr/share/zabbix-sql-scripts/postgresql/timescaledb.sql | sudo -u zabbix psql zabbix

  ;;

"mysql")

  # Install MySQL

  out "Installing MySQL" GREEN 1

  sudo cd /tmp
  sudo wget https://r.mariadb.com/downloads/mariadb_repo_setup
  sudo chmod +x /tmp/mariadb_repo_setup
  sudo /tmp/mariadb_repo_setup --mariadb-server-version="mariadb-10.5"
  sudo dnf install -y MariaDB-server-10.5.17-1.el8.x86_64

  out "Starting MySQL" GREEN 1

  sudo systemctl enable --now mariadb.service

  # Create zabbix user / DB

  out "Creating zabbix user / DB ..." GREEN 1

  SQL="create database zabbix character set utf8 collate utf8_bin;"
  SQL+="create user zabbix@localhost identified by 'password';"
  SQL+="grant all privileges on zabbix.* to zabbix@localhost;"

  sudo mysql -uroot -e "$SQL"

  sudo zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -ppassword zabbix

  ;;

esac

#
#      -> Start zabbix!
#

out "Starting Zabbix" GREEN 0 "#\n#"

sudo systemctl enable --now zabbix-server zabbix-agent $ZABBIX_WEB_SERVER_service php-fpm zabbix-java-gateway

#
#        -> Install and start Grafana
#

if $INSTALL_GRAFANA

then

  # Install

  out "Install and start Grafana" GREEN 0 "#\n#"

  out "Installing grafana" GREEN 1

  sudo cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

  sudo dnf makecache -y 
  sudo dnf -y install grafana
  sudo grafana-cli plugins install alexanderzobnin-zabbix-app

  # Install alexanderzobnin-zabbix-datasource plugin

  out "Installing alexanderzobnin-zabbix-datasource plugin" GREEN 1

  sudo echo "[plugins]" >> /etc/grafana/grafana.ini
  sudo echo "allow_loading_unsigned_plugins = true" >> /etc/grafana/grafana.ini
  sudo echo "allow_loading_unsigned_plugins = alexanderzobnin-zabbix-datasource" >> /etc/grafana/grafana.ini

  # Start

  out "Starting grafana" GREEN 1

  sudo systemctl daemon-reload && sudo systemctl enable --now grafana-server

fi

#
#        -> Install and start Prometheus
#

if $INSTALL_PROMETHEUS

then

  # Install

  out "Install and start Prometheus" GREEN 0 "#\n#"

  out "Installing prometheus" GREEN 1

  sudo useradd -m -s /bin/false prometheus

  sudo mkdir /etc/prometheus
  sudo mkdir /var/lib/prometheus

  sudo wget https://github.com/prometheus/prometheus/releases/download/v2.39.0/prometheus-2.39.0.linux-amd64.tar.gz -P /tmp

  sudo tar -xf /tmp/prometheus-2.39.0.linux-amd64.tar.gz -C /var/lib/prometheus/ --strip-components=1

  sudo chown prometheus:prometheus /etc/prometheus
  sudo chown -R prometheus:prometheus /var/lib/prometheus

  sudo cp -s /var/lib/prometheus/prometheus /usr/bin
  sudo cp -s /var/lib/prometheus/promtool /usr/bin

  # Configure Prometheus

  sudo mv /var/lib/prometheus/prometheus.yml /etc/prometheus/

  # Configure prometheus service

  sudo cat <<EOF | sudo tee /usr/lib/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/var/lib/prometheus/consoles \
--web.console.libraries=/var/lib/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

  # Start

  out "Starting prometheus" GREEN 1

  sudo systemctl enable --now prometheus.service

fi

#
#       -> Bonus Packages
#

if $INSTALL_BONUS 

then

  out "Install Bonus Packages" GREEN 0 "#\n#"

  # Install yum packages

  out "Installing jq git python36 nodejs" GREEN 1

  sudo dnf install -y jq git python36 nodejs

  # Install pyzabbix (as vagrant user instead of root)

  out "Installing pyzabbix" GREEN 1

  pip3 install pyzabbix 

  # Install pyzabbix 

  mkdir -p /home/vagrant/scripts/pyzabbix/API

  sudo cat <<EOF | sudo tee /home/vagrant/scripts/pyzabbix/API/test.py
#!/usr/bin/python3

from pyzabbix import ZabbixAPI

zapi = ZabbixAPI("ZABBIX_URL")

# User/Pass (static)
zapi.login("Admin", "zabbix")

# API Token (dynamic)
#zapi.login(api_token='d37ac712a323f695f11dfa527ec312b93754b98d4ba0c947cd6879dd01698b0d')

print("Connected to Zabbix API Version %s" % zapi.api_version())
EOF

  sudo chmod 755 /home/vagrant/scripts/pyzabbix/API/test.py
  sudo sed -i "s|ZABBIX_URL|${ZABBIX_URL}|g" /home/vagrant/scripts/pyzabbix/API/test.py

  # Make zabbix-cli shell mode available

  cd /home/vagrant
  echo "Admin::zabbix" > ~/.zabbix-cli_auth
  chmod 400 ~/.zabbix-cli_auth
  chown vagrant.vagrant ~/.zabbix-cli_auth
  sudo mv /root/.zabbix-cli_auth .

  # Install zabbix-cli (for vagrant user)

  out "Installing zabbix-cli" GREEN 1

  sudo ln -s /usr/bin/python3 /usr/bin/python

  git clone https://github.com/unioslo/zabbix-cli
  cd zabbix-cli
  sudo ./setup.py install

  # Clean

  cd .. && sudo rm -rf /home/vagrant/zabbix-cli/ 

  # Configure zabbix-cli

  sudo mkdir -p /home/vagrant/.zabbix-cli/

  sudo cat <<EOF | sudo tee /home/vagrant/.zabbix-cli/zabbix-cli.conf
[zabbix_api]
zabbix_api_url = ZABBIX_URL
cert_verify = ON

[zabbix_config]
system_id = zabbix-ID
default_hostgroup = All-hosts
default_admin_usergroup = Zabbix-root
default_create_user_usergroup = All-users
default_notification_users_usergroup = All-notification-users
default_directory_exports = /home/vagrant/zabbix_exports
default_export_format = XML
include_timestamp_export_filename = ON
use_colors = ON
use_auth_token_file = OFF
use_paging = OFF

[logging]
logging = OFF
log_level = INFO
log_file = /home/vagrant/.zabbix-cli/zabbix-cli.log
EOF

  sudo sed -i "s|ZABBIX_URL|${ZABBIX_URL}|g" /home/vagrant/.zabbix-cli/zabbix-cli.conf

fi

#
#      -> Zabbix Awesome Monitoring Environment deployment done! Show Info
#

out "ZAME : Zabbix Awesome Monitoring Environment deployment done! Show info!" GREEN 0 "#\n#"

cd /tmp

# Hostname . OS

echo -e "\n${GREEN}hostname: $(hostname)$NC"
echo -e "  -> $(sudo cat /etc/redhat-release)\n"

# Zabbix-*

echo -e "$GREEN$(zabbix_server --version | head -1)$NC"
echo -e "  -> $(zabbix_js --version | grep zabbix_)"
echo -e "  -> $(zabbix_get --version | grep zabbix_)"
echo -e "  -> $(zabbix_sender --version | grep zabbix_)\n"
echo -e "$GREEN$(ls /usr/share/zabbix-java-gateway/bin)$NC\n"

# DB

case $ZABBIX_DB_SERVER in

"mysql")
  echo -e "$GREEN$(mariadb --version 2>&1 | cut -f1 -d",")$NC"
  ;;

"pgsql")
  echo -e "$GREEN$(psql -V 2>&1)$NC"
  echo -e "  -> timescaledb2 $(sudo -u zabbix PGPASSWORD=password psql -hlocalhost -Uzabbix zabbix -c "SELECT default_version, installed_version FROM pg_available_extensions where name = 'timescaledb'" 2>&1 | tail -3 | awk '{ print $3 }')"
  ;;

esac

echo -e "  -> DB: zabbix"
echo -e "     -> ${RED}USER: zabbix$NC"
echo -e "     -> ${RED}PASSWORD: password$NC"

# Webserver

case $ZABBIX_WEB_SERVER in

"nginx")
  echo -e "\n$GREEN$(nginx -v 2>&1 | awk '{ print $3 }')$NC"
  ;;

"apache")
  echo -e "\n$GREEN$(httpd -v 2>&1 | grep version)$NC"
  ;;

esac

# Finish it!

echo -e "\n${YELLOW}Please access the frontend and finish the installation$NC"
echo -e "  -> $GREEN$ZABBIX_URL$NC"
echo -e "     -> Default credentials: ${RED}Admin/zabbix$NC"
echo -e "  -> Next step"
echo -e "  -> Next step"
echo -e "  -> Put password for zabbix user. Next step"
echo -e "  -> Put hostname for zabbix server name. Next step"
echo -e "  -> Next step"
echo -e "  -> Finish"
echo -e "$GREEN     -> Congratulations! You have successfully installed Zabbix frontend!$NC"

# Grafana

if $INSTALL_GRAFANA

then

  echo -e "\n${GREEN}grafana $(grafana-server -v 2>&1 | awk '{ print $2 }')$NC"
  echo -e "  -> ${GREEN}http://127.0.0.1:3000$NC"
  echo -e "     -> Default credentials: ${RED}admin/admin$NC"
  echo -e "  -> $(grafana-cli plugins ls | grep zabbix)"
  echo -e "     -> Plugins -> search for zabbix -> ${YELLOW}enable$NC"
  echo -e "     -> Data sources -> add data source -> search for zabbix -> ${YELLOW}configure$NC"
  echo -e "        -> URL: ${GREEN}${ZABBIX_URL}/api_jsonrpc.php$NC" 
  echo -e "        -> Username:${RED}Admin$NC"
  echo -e "        -> Password:${RED}zabbix$NC"
  echo -e "           -> Save & test"

fi

# Prometheus

if $INSTALL_PROMETHEUS

then

  echo -e "\n${GREEN}prometheus $(prometheus --version 2>&1 | head -1 | awk '{ print $3 }')$NC"
  echo -e "  -> ${GREEN}http://127.0.0.1:9090$NC"

fi

# Bonus  

if $INSTALL_BONUS

then

  echo -e "\n${GREEN}Bonus$NC"
  echo -e "  -> $(jq --version)"
  echo -e "  -> $(git --version)"
  echo -e "  -> $(python3 -V)"
  echo -e "     -> pyzabbix 1.2.1"
  echo -e "     -> zabbix-cli 2.3.1"
  echo -e "  -> nodejs $(node --version)"
  echo -e "  -> perl $(perl -v | grep version | awk '{ print $9 }' | sed 's|[)(]||g')"
  echo -e "  -> java $(java -version 2>&1 | head -1 | sed 's|"||g')"
  echo -e "  -> nc wget telnet net-tools net-snmp-utils" 

fi

# Zabbix API test message 

if $INSTALL_BONUS

then

  echo -e "\n\n\nYou can test zabbix API from pyzabbix/zabbix-cli"
  echo -e "  -> vagrant ssh"
  echo -e "     -> ./scripts/pyzabbix/API/test.py"
  echo -e "        Connected to Zabbix API Version 6.0.14\n"
  echo -e "     -> zabbix-cli -C clear | grep Connected"
  echo -e "        Connected to server $ZABBIX_URL (v6.0.14)\n" 

fi
