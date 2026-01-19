#!/bin/bash
set -euxo pipefail

# -----------------------------
# Redirect output to log file
# -----------------------------
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# -----------------------------
# Update system
# -----------------------------
sudo yum update -y
sudo yum upgrade -y

# -----------------------------
# Install Amazon SSM Agent & Session Manager plugin
# -----------------------------
# Install SSM agent
sudo dnf install -y "https://s3.${region}.amazonaws.com/amazon-ssm-${region}/latest/linux_amd64/amazon-ssm-agent.rpm"

# Download Session Manager plugin
curl -fsSL https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm -o session-manager-plugin.rpm
sudo yum install -y session-manager-plugin.rpm

# Start and enable SSM agent
sudo systemctl daemon-reload
sudo systemctl enable --now amazon-ssm-agent

# Wait for SSM to register
echo "Waiting for SSM Agent to come online..."
for i in {1..12}; do
    if sudo systemctl is-active --quiet amazon-ssm-agent; then
        echo "SSM Agent is active."
        break
    fi
    echo "SSM Agent not yet active. Retrying in 10s..."
    sleep 10
done

# -----------------------------
# Install base tools and Java
# -----------------------------
sudo yum install -y wget maven git python3-pip unzip java-17-openjdk

# -----------------------------
# Jenkins installation
# -----------------------------
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum install -y jenkins

# Run Jenkins as root for lab (matches tutor)
sudo sed -i 's/^User=jenkins/User=root/' /usr/lib/systemd/system/jenkins.service
sudo systemctl daemon-reload
sudo systemctl enable --now jenkins
sudo usermod -aG jenkins ec2-user

# -----------------------------
# Docker installation
# -----------------------------
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl start docker
sudo systemctl enable docker
# Add Jenkins & EC2 user to docker group
sudo usermod -aG docker ec2-user
sudo usermod -aG docker jenkins
sudo chmod 777 /var/run/docker.sock

# -----------------------------
# AWS CLI
# -----------------------------
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
sudo yum install -y unzip
unzip awscliv2.zip
sudo ./aws/install

# -----------------------------
# Trivy
# -----------------------------
sudo tee /etc/yum.repos.d/trivy.repo << 'EOF'
[trivy]
name=Trivy repository
baseurl=https://get.trivy.dev/rpm/releases/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://get.trivy.dev/rpm/public.key
EOF
sudo yum -y update
sudo yum -y install trivy

# -----------------------------
# New Relic (optional)
# -----------------------------
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
sudo NEW_RELIC_API_KEY="${nr_key}" \
     NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
     NEW_RELIC_REGION="EU" \
     /usr/local/bin/newrelic install -y || true

# -----------------------------
# Hostname
# -----------------------------
sudo hostnamectl set-hostname Jenkins-Server


