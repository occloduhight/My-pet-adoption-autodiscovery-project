#!/bin/bash
apt-get update -y
apt-get install -y unzip awscli fail2ban

# Install and start SSM agent
apt-get install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Enable and start Fail2ban for security hardening
systemctl enable fail2ban
systemctl start fail2ban

# Secure SSH configuration: disable root login and password authentication
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

# Create SSH directory for ec2-user
mkdir -p /home/ubuntu/.ssh
# Copy the private key into the .ssh directory
echo "${private_key}" > /home/ubuntu/.ssh/id_rsa
# Set correct permissions and ownership
chmod 400 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa

# Set hostname
hostnamectl set-hostname bastion

echo "===== Bastion Host setup complete. Connect via AWS SSM Session Manager. ====="