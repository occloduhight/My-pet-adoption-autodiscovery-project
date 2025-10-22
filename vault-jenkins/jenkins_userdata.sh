# #!/bin/bash
# set -euxo pipefail

# # Detect package manager
# if command -v dnf &>/dev/null; then
#     PKG_MANAGER="dnf"
# else
#     PKG_MANAGER="yum"
# fi

# sudo $PKG_MANAGER update -y
# sudo $PKG_MANAGER install -y wget git maven unzip yum-utils curl

# # Install SSM Agent
# sudo $PKG_MANAGER install -y amazon-ssm-agent || \
# sudo $PKG_MANAGER install -y "https://s3.${region}.amazonaws.com/amazon-ssm-agent/latest/linux_amd64/amazon-ssm-agent.rpm"
# sudo systemctl enable --now amazon-ssm-agent
# # Enable and start the SSM Agent
# sudo systemctl enable amazon-ssm-agent
# sudo systemctl start amazon-ssm-agent
# # Install Jenkins & Java
# sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
# sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
# sudo $PKG_MANAGER install -y java-17-openjdk jenkins
# sudo systemctl daemon-reload
# sudo systemctl enable --now jenkins
# sleep 10

# # Install Docker
# sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
# sudo $PKG_MANAGER install -y docker-ce
# sudo systemctl enable --now docker
# sudo usermod -aG docker ec2-user
# sudo usermod -aG docker jenkins


# # -------------------------------------------
# # Install Trivy (Aqua Security Vulnerability Scanner)
# # -------------------------------------------
# RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]+' /etc/os-release || echo "8")

# cat <<EOT | sudo tee /etc/yum.repos.d/trivy.repo
# [trivy]
# name=Trivy Repository
# baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\\$RELEASE_VERSION/
# gpgcheck=0
# enabled=1
# EOT

# sudo $PKG_MANAGER update -y
# sudo $PKG_MANAGER install -y trivy

# # Install AWS CLI v2
# curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
# unzip -q awscliv2.zip
# sudo ./aws/install

# # Install New Relic CLI
# curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
# sudo NEW_RELIC_API_KEY="${nr_key}" \
#      NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
#      NEW_RELIC_REGION="EU" \
#      /usr/local/bin/newrelic install

# # Set hostname
# sudo hostnamectl set-hostname jenkins

# # Log verification
# echo "==== Jenkins Installation Complete ===="
# sudo systemctl status jenkins | grep Active
# docker --version
# java -version
# aws --version
# newrelic --version || echo "New Relic CLI not found"
# #!/bin/bash
# set -euxo pipefail

# # Detect package manager (Amazon Linux 2 / RHEL)
# if command -v dnf &>/dev/null; then
#     PKG_MANAGER="dnf"
# else
#     PKG_MANAGER="yum"
# fi

# region=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# # Update and install base tools
# sudo $PKG_MANAGER update -y
# sudo $PKG_MANAGER install -y wget git maven unzip yum-utils curl

# # # ------------------------------------------------------------
# # # Install and enable SSM Agent
# # # ------------------------------------------------------------
# # if ! command -v amazon-ssm-agent &>/dev/null; then
# #   echo "Installing AWS SSM Agent..."
# #   sudo $PKG_MANAGER install -y amazon-ssm-agent || \
# #   sudo $PKG_MANAGER install -y "https://s3.${region}.amazonaws.com/amazon-ssm-${region}/latest/linux_amd64/amazon-ssm-agent.rpm"
# # fi

# # sudo systemctl enable amazon-ssm-agent
# # sudo systemctl start amazon-ssm-agent

# # ------------------------------------------------------------
# # Install and enable SSM Agent (robust version)
# # ------------------------------------------------------------

# # Detect the region from instance metadata
# region=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# # Detect package manager
# if command -v dnf &>/dev/null; then
#     PKG_MANAGER="dnf"
# else
#     PKG_MANAGER="yum"
# fi

# # Install SSM Agent if not already installed
# if ! command -v amazon-ssm-agent &>/dev/null; then
#     echo "Installing AWS SSM Agent..."
#     sudo $PKG_MANAGER install -y amazon-ssm-agent || \
#     sudo $PKG_MANAGER install -y "https://s3.${region}.amazonaws.com/amazon-ssm-agent/latest/linux_amd64/amazon-ssm-agent.rpm"
# fi

# # Enable and start the service
# sudo systemctl enable amazon-ssm-agent
# sudo systemctl start amazon-ssm-agent

# # Wait a few seconds for networking to be ready, then restart SSM agent
# sleep 10
# sudo systemctl restart amazon-ssm-agent

# # Optional: check status
# sudo systemctl status amazon-ssm-agent | grep Active

# # ------------------------------------------------------------
# # Install Jenkins & Java
# # ------------------------------------------------------------
# sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
# sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
# sudo $PKG_MANAGER install -y java-17-openjdk jenkins
# sudo systemctl daemon-reload
# sudo systemctl enable --now jenkins
# sleep 10

# # ------------------------------------------------------------
# # Install Docker
# # ------------------------------------------------------------
# sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
# sudo $PKG_MANAGER install -y docker-ce
# sudo systemctl enable --now docker
# sudo usermod -aG docker ec2-user || true
# sudo usermod -aG docker jenkins || true

# # ------------------------------------------------------------
# # Install Trivy (Aqua Security Vulnerability Scanner)
# # ------------------------------------------------------------
# RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]+' /etc/os-release || echo "8")

# cat <<EOT | sudo tee /etc/yum.repos.d/trivy.repo
# [trivy]
# name=Trivy Repository
# baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\\$RELEASE_VERSION/
# gpgcheck=0
# enabled=1
# EOT

# sudo $PKG_MANAGER update -y
# sudo $PKG_MANAGER install -y trivy

# # ------------------------------------------------------------
# # Install AWS CLI v2
# # ------------------------------------------------------------
# curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
# unzip -q awscliv2.zip
# sudo ./aws/install
# rm -rf aws awscliv2.zip

# # ------------------------------------------------------------
# # Install New Relic CLI
# # ------------------------------------------------------------
# curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
# sudo NEW_RELIC_API_KEY="${nr_key}" \
#      NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
#      NEW_RELIC_REGION="EU" \
#      /usr/local/bin/newrelic install

# # ------------------------------------------------------------
# # Final setup
# # ------------------------------------------------------------
# sudo hostnamectl set-hostname jenkins

# echo "==== Jenkins Installation Complete ===="
# sudo systemctl status jenkins | grep Active || true
# docker --version
# java -version
# aws --version
# newrelic --version || echo "New Relic CLI not found"


#!/bin/bash
set -euxo pipefail

# -----------------------------------------
# Detect region dynamically from EC2 metadata
# -----------------------------------------
region=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Detect package manager
if command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
else
    PKG_MANAGER="yum"
fi

# -----------------------------------------
# Update OS and install essentials
# -----------------------------------------
sudo $PKG_MANAGER update -y
sudo $PKG_MANAGER install -y wget git maven unzip yum-utils curl || true

# -----------------------------------------
# Install and enable SSM Agent (robust)
# -----------------------------------------
if ! command -v amazon-ssm-agent &>/dev/null; then
    echo "Installing AWS SSM Agent..."
    sudo $PKG_MANAGER install -y "https://s3.${region}.amazonaws.com/amazon-ssm-agent/latest/linux_amd64/amazon-ssm-agent.rpm" || true
fi

sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
sleep 10
sudo systemctl restart amazon-ssm-agent
sudo systemctl status amazon-ssm-agent | grep Active || true

# Install session manager plugin (optional for CLI SSM)
curl -sSf "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o session-manager-plugin.rpm
sudo $PKG_MANAGER install -y session-manager-plugin.rpm || true

# -----------------------------------------
# Jenkins setup
# -----------------------------------------
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key || true
sudo $PKG_MANAGER install -y java-17-openjdk jenkins || true
sudo systemctl daemon-reload
sudo systemctl enable --now jenkins || true

# -----------------------------------------
# Docker installation
# -----------------------------------------
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo $PKG_MANAGER install -y docker-ce || true
sudo systemctl enable --now docker || true
sudo usermod -aG docker ec2-user || true
sudo usermod -aG docker jenkins || true

# -----------------------------------------
# Trivy installation
# -----------------------------------------
RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]+' /etc/os-release || echo "8")
cat <<EOT | sudo tee /etc/yum.repos.d/trivy.repo
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$RELEASE_VERSION/
gpgcheck=0
enabled=1
EOT
sudo $PKG_MANAGER update -y || true
sudo $PKG_MANAGER install -y trivy || true

# -----------------------------------------
# AWS CLI v2 installation
# -----------------------------------------
curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip || true
sudo ./aws/install || true

# -----------------------------------------
# New Relic installation (if license provided)
# -----------------------------------------
if [ -n "${nr_key}" ]; then
    curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash || true
    sudo NEW_RELIC_API_KEY="${nr_key}" NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" NEW_RELIC_REGION="EU" /usr/local/bin/newrelic install || true
fi

# -----------------------------------------
# Set hostname
# -----------------------------------------
sudo hostnamectl set-hostname jenkins || true