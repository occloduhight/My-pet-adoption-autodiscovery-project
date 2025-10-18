# #!/bin/bash
# # Update OS
# sudo yum update -y
# # install dependencies-wget,pip,git,maven
# sudo yum install wget git pip maven -y
# # install amazon-ssm-agent
# sudo dnf install -y https://s3.s3.eu-west-3.amazonaws.com/amazon-ssm-s3.eu-west-3/latest/linux_amd64/amazon-ssm-agent.rpm
# curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
# sudo yum install -y session-manager-plugin.rpm
# sudo systemctl enable amazon-ssm-agent
# sudo systemctl start amazon-ssm-agent

# # get jenkins repo
# sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
# #import jenkins key
# sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
# sudo yum upgrade -y
# # install  java first and then jenkins
# sudo yum install java-17-openjdk -y
# sudo yum install jenkins -y
# #enable systemd integration on jenkins
# sudo sed -i 's/^User=jenkins/User=root/' /usr/lib/systemd/system/jenkins.service
# sudo systemctl daemon-reload
# sudo systemctl start jenkins
# sudo systemctl enable jenkins
# sudo systemctl start jenkins
# sudo usermod -aG jenkins ec2-user

# # Install trivy for container scanning
# RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]' /etc/os-release)
# cat << EOT | sudo tee -a /etc/yum.repos.d/trivy.repo
# [trivy]
# name=Trivy repository
# baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$RELEASE_VERSION/\$basearch/
# gpgcheck=0
# enabled=1
# EOT
# sudo yum -y update
# sudo yum -y install trivy

# # # install docker
# # sudo yum install -y yum-utils
# # sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
# # sudo yum install docker-ce -y
# # sudo service docker start
# # sudo systemctl start docker
# # sudo systemctl enable docker
# # # add jenkins and ec2-user to docker group
# # sudo usermod -aG docker ec2-user
# # sudo usermod -aG docker jenkins
# # sudo chmod 777 /var/run/docker.sock

# # Installing awscli
# sudo yum install unzip -y
# curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
# unzip awscliv2.zip
# sudo ./aws/install
# sudo ln -svf /usr/local/bin/aws /usr/bin/aws

# # install newrelic agent safely with environment variables
# curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && \
# sudo NEW_RELIC_API_KEY="${nr_key}" \
#      NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
#      NEW_RELIC_REGION="EU" \
#      /usr/local/bin/newrelic install
# # set hostname to jenkins
# sudo hostnamectl set-hostname jenkins



#!/bin/bash
set -euxo pipefail

# This user-data is executed on instance boot. It expects the following template
# variables to be supplied by Terraform's templatefile(): region, newrelic_license

sudo yum update -y

# Install essentials (adjust per-AMI if needed)
sudo yum install -y wget git maven unzip

# Install amazon-ssm-agent (region-aware)
sudo dnf install -y "https://s3.${region}.amazonaws.com/amazon-ssm-${region}/latest/linux_amd64/amazon-ssm-agent.rpm" || true
curl -sSf "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o session-manager-plugin.rpm
sudo yum install -y session-manager-plugin.rpm || true

# Jenkins repo and package
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key || true
sudo yum install -y java-17-openjdk jenkins || true

# Start and enable services
sudo systemctl daemon-reload
sudo systemctl enable --now jenkins || true

# Ensure docker is installed and started
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce || true
sudo systemctl enable --now docker || true

# Add jenkins and ec2-user to docker group (no insecure chmod on docker socket)
sudo usermod -aG docker ec2-user || true
sudo usermod -aG docker jenkins || true

# Install trivy for container scanning (best-effort)
RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]+' /etc/os-release || echo "8")
cat << EOT | sudo tee /etc/yum.repos.d/trivy.repo
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$RELEASE_VERSION/
gpgcheck=0
enabled=1
EOT
sudo yum -y update || true
sudo yum -y install trivy || true

# Installing AWS CLI v2
curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip || true
sudo ./aws/install || true

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && \
sudo NEW_RELIC_API_KEY="${nr_key}" \
     NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
     NEW_RELIC_REGION="EU" \
     /usr/local/bin/newrelic install
# Set hostname for clarity
sudo hostnamectl set-hostname jenkins || true







