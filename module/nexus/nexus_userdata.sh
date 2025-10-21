#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
#NEXUS_VERSION="3.80.0-06-linux-x86_64"
NEXUS_USER="nexus"
NEXUS_INSTALL_DIR="/opt/nexus"
NEXUS_DATA_DIR="/opt/sonatype-work"
DOWNLOAD_URL="https://download.sonatype.com/nexus/3/nexus-3.80.0-06-linux-x86_64.tar.gz
"

# 1. Install Java (required by Nexus)
echo "Updating packages..."
sudo dnf update -y
echo "Installing Java..."
sudo dnf install java-21-openjdk java-21-openjdk-devel wget -y

# install amazon-ssm-agent
sudo dnf install -y https://s3.eu-west-1.amazonaws.com/amazon-ssm-eu-west-1/latest/linux_amd64/amazon-ssm-agent.rpm
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo yum install -y session-manager-plugin.rpm


# 2. Add nexus user
echo "Adding nexus user..."
sudo useradd -r -M -d ${NEXUS_INSTALL_DIR} -s /bin/false ${NEXUS_USER} || true

# Ensure home directory is correctly set
sudo usermod -d ${NEXUS_INSTALL_DIR} ${NEXUS_USER}

# 3. Download and extract Nexus
echo "Downloading Nexus ..."
cd /tmp
sudo wget -O nexus.tar.gz ${DOWNLOAD_URL}
tar -xzf  nexus.tar.gz


# 4. Move Nexus to /opt and set permissions
echo "Moving Nexus install dir and data dir ..."
#sudo mv nexus ${NEXUS_INSTALL_DIR}
sudo mv nexus-3.80.0-06/ ${NEXUS_INSTALL_DIR}
sudo mv sonatype-work ${NEXUS_DATA_DIR}
# Make sure the binary is executable
echo "Making Nexus binary executable..."
sudo chmod +x ${NEXUS_INSTALL_DIR}/bin/nexus
# Ensure the user can traverse directories
echo "Ensuring path permissions are accessible..."
sudo chmod +x /opt
sudo chmod -R u+rx ${NEXUS_INSTALL_DIR}/bin

sudo chown -R ${NEXUS_USER}:${NEXUS_USER} ${NEXUS_INSTALL_DIR}
sudo chown -R ${NEXUS_USER}:${NEXUS_USER} ${NEXUS_DATA_DIR}

# 5. Configure Nexus to run as nexus user
echo "Configuring Nexus to run as ${NEXUS_USER}..."
echo "run_as_user=${NEXUS_USER}" | sudo tee ${NEXUS_INSTALL_DIR}/bin/nexus.rc

# 6. Create systemd service file
echo "Creating systemd service..."
sudo tee /etc/systemd/system/nexus.service > /dev/null <<EOF
[Unit]
Description=nexus service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=${NEXUS_INSTALL_DIR}/bin/nexus start
ExecStop=${NEXUS_INSTALL_DIR}/bin/nexus stop
User=${NEXUS_USER}
Restart=on-abort
Environment=HOME=${NEXUS_INSTALL_DIR}
WorkingDirectory=${NEXUS_INSTALL_DIR}

[Install]
WantedBy=multi-user.target
EOF

# 7.  Handle SELinux
echo "Checking SELinux status..."
SELINUX_STATUS=$(getenforce)

if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
  echo "Disabling SELinux temporarily..."
  sudo setenforce 0

  echo "Disabling SELinux permanently..."
  sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
  echo "SELinux set to disabled. A reboot is required to apply this permanently."
else
  echo "SELinux is already in $SELINUX_STATUS mode."
fi

# 8. Enable and start the Nexus service
echo "Enabling and starting Nexus..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable nexus
sudo systemctl start nexus

# 9. Show Nexus status and default admin password path
echo " Nexus is installed and running on port 8081"
echo "Check status: sudo systemctl status nexus"
#echo "Default admin password: sudo cat ${NEXUS_DATA_DIR}/admin.password"
