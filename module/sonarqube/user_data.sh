#!/bin/bash

set -e

# Variables
SONAR_VERSION="10.6.0.92116"
SONAR_USER="sonarqube"
SONAR_DIR="/opt/sonarqube"
DB_NAME="sonarqube"
DB_USER="sonaruser"
DB_PASS="StrongPassword123!"

echo "---- Updating system packages ----"
sudo apt update -y && sudo apt upgrade -y

echo "---- Installing required dependencies ----"
sudo apt install -y wget unzip openjdk-17-jdk postgresql postgresql-contrib

echo "---- Configuring PostgreSQL Database ----"
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Create SonarQube database and user
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" || true
sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" || true

echo "---- Downloading SonarQube ----"
cd /opt
sudo wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip
sudo unzip -q sonarqube-$SONAR_VERSION.zip
sudo mv sonarqube-$SONAR_VERSION sonarqube
sudo rm -f sonarqube-$SONAR_VERSION.zip

echo "---- Creating SonarQube user ----"
sudo useradd --system --no-create-home --shell /bin/bash $SONAR_USER || true
sudo chown -R $SONAR_USER:$SONAR_USER $SONAR_DIR

echo "---- Configuring SonarQube database connection ----"
sudo sed -i "s|#sonar.jdbc.username=.*|sonar.jdbc.username=$DB_USER|g" $SONAR_DIR/conf/sonar.properties
sudo sed -i "s|#sonar.jdbc.password=.*|sonar.jdbc.password=$DB_PASS|g" $SONAR_DIR/conf/sonar.properties
sudo sed -i "s|#sonar.jdbc.url=jdbc:postgresql.*|sonar.jdbc.url=jdbc:postgresql://localhost/$DB_NAME|g" $SONAR_DIR/conf/sonar.properties

echo "---- Adjusting system limits ----"
sudo bash -c 'cat >> /etc/security/limits.conf <<EOF
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096
EOF'

echo "---- Configuring SonarQube to run as a service ----"
cat <<EOF | sudo tee /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube Service
After=network.target syslog.target

[Service]
Type=forking
ExecStart=$SONAR_DIR/bin/linux-x86-64/sonar.sh start
ExecStop=$SONAR_DIR/bin/linux-x86-64/sonar.sh stop
User=$SONAR_USER
Group=$SONAR_USER
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

echo "---- Setting kernel parameters ----"
sudo bash -c 'cat >> /etc/sysctl.conf <<EOF
vm.max_map_count=262144
fs.file-max=65536
EOF'
sudo sysctl -p

echo "---- Enabling and starting SonarQube ----"
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

echo "---- Checking SonarQube status ----"
sudo systemctl status sonarqube --no-pager

echo "---- Installation complete! ----"
echo "SonarQube is running at: http://<your-ec2-public-ip>:9000"
echo "Default login: admin / admin"

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo  NEW_RELIC_API_KEY="${nr_key}" NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y

sudo hostnamectl set-hostname SonarQube