#!/bin/bash

# Update and upgrade system packages
sudo apt update -y
sudo apt upgrade -y

# Install prerequisites for Docker
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker GPG key and repository
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add ec2-user to Docker group
sudo usermod -aG docker ec2-user

# Set hostname
sudo hostnamectl set-hostname prod-asg

# Install New Relic CLI and agent
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash

# Run New Relic installation
sudo NEW_RELIC_API_KEY="${nr_key}" NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y
