#!/bin/bash
# Create SSH directory for ec2-user
mkdir -p /home/ec2-user/.ssh
# Copy the private key into the .ssh directory
echo "${privatekey}" > /home/ec2-user/.ssh/id_rsa
# Set correct permissions and ownership
chmod 400 /home/ec2-user/.ssh/id_rsa
chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa

# Set hostname
hostnamectl set-hostname bastion

# Install New Relic
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && \
sudo NEW_RELIC_API_KEY="${nr-key}" \
     NEW_RELIC_ACCOUNT_ID="${nr-acc-id}" \
     NEW_RELIC_REGION=EU \
     /usr/local/bin/newrelic install -y
