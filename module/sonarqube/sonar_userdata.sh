#!/bin/bash

set -e

# === CONFIGURATION ===
SONAR_VERSION="25.5.0.107428"
SONAR_USER="sonaruser"
SONAR_DIR="/opt/sonarqube"
DB_USER="sonar"
DB_PASSWORD="StrongPassword123"
DB_NAME="sonarqube"
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}"


# === INSTALL DEPENDENCIES ===
apt update
apt install -y openjdk-17-jdk unzip wget postgresql ufw

# === CREATE SONAR SYSTEM USER WITHOUT LOGIN ===
useradd -r -s /bin/false $SONAR_USER

# === DOWNLOAD AND EXTRACT SONARQUBE ===
cd /opt
wget $SONAR_URL
unzip $SONAR_ZIP
mv sonarqube-${SONAR_VERSION} sonarqube
chown -R $SONAR_USER:$SONAR_USER $SONAR_DIR

# === CONFIGURE POSTGRESQL ===
sudo -u postgres psql <<EOF
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '${DB_PASSWORD}';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

# === CONFIGURE sonar.properties ===
SONAR_PROP="$SONAR_DIR/conf/sonar.properties"
sed -i "s|#sonar.jdbc.username=.*|sonar.jdbc.username=${DB_USER}|" $SONAR_PROP
sed -i "s|#sonar.jdbc.password=.*|sonar.jdbc.password=${DB_PASSWORD}|" $SONAR_PROP
sed -i "s|#sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://localhost/${DB_NAME}|" $SONAR_PROP

# === INCREASE FILE LIMITS ===
echo "$SONAR_USER soft nofile 65536" >> /etc/security/limits.conf
echo "$SONAR_USER hard nofile 65536" >> /etc/security/limits.conf
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -w vm.max_map_count=262144

# === CREATE SYSTEMD SERVICE ===
cat <<EOF > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=forking
ExecStart=$SONAR_DIR/bin/linux-x86-64/sonar.sh start
ExecStop=$SONAR_DIR/bin/linux-x86-64/sonar.sh stop
User=$SONAR_USER
Group=$SONAR_USER
LimitNOFILE=65536
LimitNPROC=4096
Restart=always

[Install]
WantedBy=multi-user.target
EOF

ufw allow 9000/tcp

# === ENABLE AND START SONARQUBE ===
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

# === DONE ===
echo "SonarQube $SONAR_VERSION installed and running"


# ====== INSTALL NGINX ===========

apt update
apt install -y nginx

# === Configure NGINX for SonarQube ===
cat <<EOF > /etc/nginx/sites-available/sonarqube
server {
    listen 80;
    server_name sonarqube.set30.site;

    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 100M;
    }

    access_log /var/log/nginx/sonarqube_access.log;
    error_log /var/log/nginx/sonarqube_error.log;
}
EOF

# Enable the site and restart NGINX
ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx