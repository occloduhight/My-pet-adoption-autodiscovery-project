#!/bin/bash

# --- 1. Define Variables ---
SONAR_VERSION="25.11.0.114957"
SONAR_USER="sonar"
SONAR_HOME="/opt/sonarqube"
SONAR_DOWNLOAD_URL="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip"
DB_NAME="sonarqube"
DB_USER="sonar"
DB_PASSWORD="Admin123!" # IMPORTANT: Change this password for production use
TEMP_EXTRACT_DIR="/tmp/sonarqube_extracted"

# --- 2. System Update, Dependencies, and Java (OpenJDK 17 LTS) ---
echo "--- Updating system packages and installing OpenJDK 17 ---"
apt update -y
apt install -y openjdk-17-jdk wget unzip postgresql postgresql-contrib nginx

# Verify Java installation
java -version

# Dynamic Java path detection (More robust than hardcoding)
echo "--- Detecting Java 17 executable path dynamically ---"
JAVA_BIN=$(readlink -f /usr/bin/java)
echo "Detected Java executable: $JAVA_BIN"

# --- 3. Configure System Kernel Parameters (Critical for SonarQube) ---
echo "--- Configuring system kernel parameters for SonarQube limits ---"
# Increase virtual memory map count (vm.max_map_count)
sysctl -w vm.max_map_count=524288
# Increase maximum file descriptors (fs.file-max)
sysctl -w fs.file-max=131072
# Make settings permanent across reboots
echo "vm.max_map_count=524288" | tee -a /etc/sysctl.conf
echo "fs.file-max=131072" | tee -a /etc/sysctl.conf

# --- 4. PostgreSQL Database Setup ---
echo "--- Configuring PostgreSQL database and user for SonarQube ---"

# Start the PostgreSQL service (if not already running)
systemctl start postgresql
systemctl enable postgresql

# Create the database and user using the 'postgres' superuser
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# --- 5. SonarQube Installation and User Setup (ROBUST FILE MOVEMENT FIX) ---
echo "--- Downloading and installing SonarQube Community Edition v$SONAR_VERSION ---"

# 5.1. Create the final destination directory
mkdir -p $SONAR_HOME

# 5.2. Download and unzip to a temporary, controlled location
wget -q $SONAR_DOWNLOAD_URL -O /tmp/sonarqube.zip
mkdir -p $TEMP_EXTRACT_DIR
unzip -q /tmp/sonarqube.zip -d $TEMP_EXTRACT_DIR

# 5.3. Move the contents of the extracted folder into the final destination
echo "Moving SonarQube files from temporary directory to $SONAR_HOME"
mv $TEMP_EXTRACT_DIR/sonarqube-$SONAR_VERSION/* $SONAR_HOME

# 5.4. Cleanup
rm -rf /tmp/sonarqube.zip $TEMP_EXTRACT_DIR

# Create a dedicated SonarQube user (required for security)
useradd -r -s /bin/false $SONAR_USER

# FIX: Set execute permissions recursively on the entire bin directory
echo "Setting recursive execute permissions on SonarQube binaries"
chmod -R +x $SONAR_HOME/bin/

# Set appropriate ownership and permissions
chown -R $SONAR_USER:$SONAR_USER $SONAR_HOME

# --- 6. Configure SonarQube to use PostgreSQL ---
echo "--- Configuring SonarQube properties ---"
CONFIG_FILE="$SONAR_HOME/conf/sonar.properties"

# Backup original configuration file
cp $CONFIG_FILE "$CONFIG_FILE.bak"

# 6.1. Database Configuration
sed -i '/#sonar.jdbc.username=/c\sonar.jdbc.username='"$DB_USER" $CONFIG_FILE
sed -i '/#sonar.jdbc.password=/c\sonar.jdbc.password='"$DB_PASSWORD" $CONFIG_FILE
sed -i '/#sonar.jdbc.url=jdbc:postgresql/c\sonar.jdbc.url=jdbc:postgresql://localhost:5432/'"$DB_NAME" $CONFIG_FILE

# 6.2. Web Server Configuration (for Nginx reverse proxy)
sed -i '/#sonar.web.host=0.0.0.0/c\sonar.web.host=127.0.0.1' $CONFIG_FILE
sed -i '/#sonar.web.context=\//c\sonar.web.context=/' $CONFIG_FILE
sed -i '/#sonar.web.port=9000/c\sonar.web.port=9000' $CONFIG_FILE

# 6.3. Set up path to Java executable using dynamic path (IMPROVED ROBUSTNESS)
sed -i '/#wrapper.java.command=/c\wrapper.java.command='"$JAVA_BIN" $SONAR_HOME/conf/wrapper.conf

# --- 7. Create Systemd Service File for SonarQube ---
# Configuring so that we can run commands to start, stop and reload sonarqube service

echo "--- Creating systemd service for SonarQube ---"
cat > /etc/systemd/system/sonarqube.service << EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=forking
ExecStart=$SONAR_HOME/bin/linux-x86-64/sonar.sh start
ExecStop=$SONAR_HOME/bin/linux-x86-64/sonar.sh stop
ExecStop=$SONAR_HOME/bin/linux-x86-64/sonar.sh restatrt
User=$SONAR_USER
Group=$SONAR_USER
Restart=always
LimitNOFILE=65536
LimitNPROC=4096
[Install]
WantedBy=multi-user.target" >> /etc/systemd/system/sonarqube.service
EOF

# Reload daemon, enable, and start SonarQube service
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube
sleep 15 # Wait for SonarQube to initialize (it can take a moment)

# --- 8. Configure Nginx Reverse Proxy ---
echo "--- Configuring Nginx reverse proxy for SonarQube on port 80 ---"

# Remove the default Nginx site configuration
rm -f /etc/nginx/sites-enabled/default

# Create the Nginx configuration file for SonarQube
cat > /etc/nginx/sites-available/sonarqube << EOF
server {
    listen 80;
    server_name _; # Use '_' or your domain name (e.g., sonar.example.com)

    # SonarQube requires a specific set of headers for websockets and connection
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Required for WebSockets
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_connect_timeout 90;
        proxy_send_timeout 90;
        proxy_read_timeout 90;
        
        # Disable cache
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }
}
EOF

# Enable the SonarQube Nginx site
ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube

# Test Nginx configuration and restart
nginx -t
systemctl restart nginx

echo "--- SonarQube Setup Complete ---"
echo "SonarQube is accessible via http://<Your-Server-IP> (proxied via Nginx on port 80)."
echo "Initial credentials are admin/admin."
echo "PostgreSQL credentials: User: $DB_USER, Password: $DB_PASSWORD"
# --------------------------------------------------------------------------------------
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${nr_key}" NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y