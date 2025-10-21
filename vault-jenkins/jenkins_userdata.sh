# #!/bin/bash
# set -euxo pipefail

# # Update system
# if command -v dnf &> /dev/null; then
#     PKG_MANAGER="dnf"
# else
#     PKG_MANAGER="yum"
# fi

# sudo $PKG_MANAGER update -y

# # Install essentials
# sudo $PKG_MANAGER install -y wget git maven unzip yum-utils

# # Install amazon-ssm-agent
# # SSM_RPM="https://s3.${region}.amazonaws.com/amazon-ssm-${region}/latest/linux_amd64/amazon-ssm-agent.rpm"
# # sudo $PKG_MANAGER install -y $SSM_RPM
# # sudo dnf install -y "https://s3.${region}.amazonaws.com/amazon-ssm-agent/latest/linux_amd64/amazon-ssm-agent.rpm" || \
# # sudo yum install -y "https://s3.${region}.amazonaws.com/amazon-ssm-agent/latest/linux_amd64/amazon-ssm-agent.rpm"
# sudo snap install amazon-ssm-agent --classic || \
# sudo yum install -y amazon-ssm-agent || \
# sudo dnf install -y amazon-ssm-agent

# # Enable and start SSM agent
# sudo systemctl enable amazon-ssm-agent
# sudo systemctl start amazon-ssm-agent

# # Install Session Manager plugin (optional, for CLI)
# curl -sSf "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o session-manager-plugin.rpm
# sudo $PKG_MANAGER install -y session-manager-plugin.rpm

# # Install Jenkins and Java
# sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
# sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
# sudo $PKG_MANAGER install -y java-17-openjdk jenkins
# sudo systemctl daemon-reload
# sudo systemctl enable --now jenkins

# # Install and start Docker
# # sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
# sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
# sudo $PKG_MANAGER install -y docker-ce
# sudo systemctl enable --now docker

# # Add jenkins and ec2-user to docker group
# sudo usermod -aG docker ec2-user
# sudo usermod -aG docker jenkins

# # Install Trivy for container scanning
# RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]+' /etc/os-release || echo "8")
# cat << EOT | sudo tee /etc/yum.repos.d/trivy.repo
# [trivy]
# name=Trivy repository
# baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/${RELEASE_VERSION}/\$basearch/
# gpgcheck=0
# enabled=1
# EOT
# sudo $PKG_MANAGER -y update
# sudo $PKG_MANAGER -y install trivy

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

# # Set hostname for clarity
# sudo hostnamectl set-hostname jenkins

#!/bin/bash
set -euxo pipefail

# Detect package manager
if command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
else
    PKG_MANAGER="yum"
fi

sudo $PKG_MANAGER update -y
sudo $PKG_MANAGER install -y wget git maven unzip yum-utils curl

# Install SSM Agent
sudo $PKG_MANAGER install -y amazon-ssm-agent || \
sudo $PKG_MANAGER install -y "https://s3.${region}.amazonaws.com/amazon-ssm-agent/latest/linux_amd64/amazon-ssm-agent.rpm"
sudo systemctl enable --now amazon-ssm-agent

# Install Jenkins & Java
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo $PKG_MANAGER install -y java-17-openjdk jenkins
sudo systemctl daemon-reload
sudo systemctl enable --now jenkins
sleep 10

# Install Docker
sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo $PKG_MANAGER install -y docker-ce
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
sudo usermod -aG docker jenkins

# # Install Trivy
# # RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]+' /etc/os-release || echo "8")
# # cat <<EOT | sudo tee /etc/yum.repos.d/trivy.repo
# # [trivy]
# # name=Trivy repository
# # baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\$RELEASE_VERSION/

# # gpgcheck=0
# # enabled=1
# # EOT
# # sudo $PKG_MANAGER update -y
# # sudo $PKG_MANAGER install -y trivy
# # Install Trivy
# RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]+' /etc/os-release || echo "8")
# cat <<EOT | sudo tee /etc/yum.repos.d/trivy.repo
# [trivy]
# name=Trivy repository
# # baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\$RELEASE_VERSION/
# baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\\$RELEASE_VERSION/
# gpgcheck=0
# enabled=1
# EOT
# sudo $PKG_MANAGER update -y
# sudo $PKG_MANAGER install -y trivy

# -------------------------------------------
# Install Trivy (Aqua Security Vulnerability Scanner)
# -------------------------------------------
RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]+' /etc/os-release || echo "8")

cat <<EOT | sudo tee /etc/yum.repos.d/trivy.repo
[trivy]
name=Trivy Repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\\$RELEASE_VERSION/
gpgcheck=0
enabled=1
EOT

sudo $PKG_MANAGER update -y
sudo $PKG_MANAGER install -y trivy

# Install AWS CLI v2
curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
sudo ./aws/install

# Install New Relic CLI
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
sudo NEW_RELIC_API_KEY="${nr_key}" \
     NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
     NEW_RELIC_REGION="EU" \
     /usr/local/bin/newrelic install

# Set hostname
sudo hostnamectl set-hostname jenkins

# Log verification
echo "==== Jenkins Installation Complete ===="
sudo systemctl status jenkins | grep Active
docker --version
java -version
aws --version
newrelic --version || echo "New Relic CLI not found"
