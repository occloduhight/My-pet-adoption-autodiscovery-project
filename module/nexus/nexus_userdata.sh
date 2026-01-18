#!/bin/bash
# Cloud-init userdata for Nexus Repository Manager + Amazon SSM Agent on Ubuntu 22.04 LTS
# Fully automated, non-interactive

set -e

# ===== Variables =====
REGION="${REGION:-eu-west-3}"            # AWS region
NEXUS_USER="nexus"
NEXUS_INSTALL_DIR="/opt/nexus"
NEXUS_DATA_DIR="/opt/sonatype-work"
NEXUS_DOWNLOAD_URL="https://download.sonatype.com/nexus/3/latest-unix.tar.gz"
SSM_URL="https://s3.${REGION}.amazonaws.com/amazon-ssm-${REGION}/latest/debian_amd64/amazon-ssm-agent.deb"

# ===== Update system =====
echo "===== Updating system ====="
apt-get update -y
apt-get upgrade -y

# ===== Install dependencies =====
echo "===== Installing dependencies ====="
apt-get install -y openjdk-11-jdk wget tar unzip curl gnupg

# ===== Create nexus user and directories =====
echo "===== Creating nexus user and directories ====="
id -u $NEXUS_USER &>/dev/null || useradd -r -m -d $NEXUS_INSTALL_DIR -s /bin/bash $NEXUS_USER
mkdir -p $NEXUS_INSTALL_DIR $NEXUS_DATA_DIR
chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_INSTALL_DIR $NEXUS_DATA_DIR

# ===== Download and install Nexus =====
echo "===== Downloading Nexus ====="
cd /opt
wget -q $NEXUS_DOWNLOAD_URL -O latest-unix.tar.gz
tar -xvzf latest-unix.tar.gz
mv nexus-* nexus
chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_INSTALL_DIR $NEXUS_DATA_DIR

# ===== Configure Nexus run user =====
echo "===== Configuring Nexus run user ====="
echo 'run_as_user="nexus"' > $NEXUS_INSTALL_DIR/bin/nexus.rc
echo 'export INSTALL4J_JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> $NEXUS_INSTALL_DIR/bin/nexus.rc
chmod +x $NEXUS_INSTALL_DIR/bin/nexus

# ===== Create systemd service for Nexus =====
echo "===== Creating systemd service for Nexus ====="
cat << 'EOF' > /etc/systemd/system/nexus.service
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
User=nexus
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# ===== Install Amazon SSM Agent =====
echo "===== Installing Amazon SSM Agent ====="
wget -q $SSM_URL -O /tmp/amazon-ssm-agent.deb
dpkg -i /tmp/amazon-ssm-agent.deb || apt-get install -f -y
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
if systemctl status amazon-ssm-agent >/dev/null 2>&1; then
    echo "SSM Agent is running"
else
    echo "SSM Agent failed to start"
fi

# ===== Enable and start Nexus service =====
echo "===== Enabling and starting Nexus service ====="
systemctl daemon-reload
systemctl enable nexus
systemctl start nexus
if systemctl status nexus >/dev/null 2>&1; then
    echo "Nexus is running on port 8081"
else
    echo "Nexus failed to start"
fi

echo "===== Installation complete ====="
