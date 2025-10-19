#!/bin/bash
set -e

# Update and install required packages
yum update -y
yum install -y docker wget curl

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Configure Docker to trust Nexus registry (insecure or internal)
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "insecure-registries" : ["${nexus_ip}:8082"]
}
EOF

# Restart Docker to apply registry config
systemctl restart docker

# # Install New Relic Infrastructure Agent
# curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/8/x86_64/newrelic-infra.repo
# yum install newrelic-infra -y

# # Configure New Relic with license key
# cat <<EOF > /etc/newrelic-infra.yml
# license_key: ${nr_key}
# display_name: docker-host
# custom_attributes:
#   environment: production
# EOF

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && \
sudo NEW_RELIC_API_KEY="${nr_key}" \
     NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
     NEW_RELIC_REGION="EU" \
     /usr/local/bin/newrelic install
# Start New Relic agent
systemctl enable newrelic-infra
systemctl start newrelic-infra
