#!/bin/bash

# Update the system
sudo dnf update -y

# Install EPEL repository (required for Ansible)
sudo dnf install -y epel-release

# Install Python3 and pip if not already installed
sudo dnf install -y python3 python3-pip

# Install Ansible
sudo dnf install -y ansible

# Install AWS CLI
sudo dnf install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -f awscliv2.zip
rm -rf aws/

# Write private key to id_rsa file
echo "${private_key}" > /home/ec2-user/.ssh/id_rsa

# Set correct permissions for the private key
sudo chmod 400 /home/ec2-user/.ssh/id_rsa
sudo chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa

# Download files from S3 bucket
aws s3 cp s3://"${s3_bucket}"/scripts/ /etc/ansible/ --recursive

# Create an ansible variable file for Nexus ip
echo "NEXUS_IP: ${nexus_ip}:8085" > /etc/ansible/ansible_variable.yml

# change directory ownership to ec2-user
sudo chown -R ec2-user:ec2-user /etc/ansible/

sudo hostnamectl set-hostname ansible