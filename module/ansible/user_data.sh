#!/bin/bash

# Updating the system and installing necessary packages

echo "--- Installing dependencies ---"
sudo dnf update -y
sudo dnf install -y python3 python3-pip git jq curl wget vim 

# --- Upgrade pip and install Ansible 2.15+ ---
python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install "ansible>=2.15" boto3 botocore

# # installing EPEL repository
# sudo dnf install epel-release -y

# # Installing python3 and pip
# sudo dnf install python3 python3-pip -y

# Installing awscli
sudo yum install wget unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -f awscliv2.zip
rm -rf aws/
sudo ln -svf /usr/local/bin/aws /usr/bin/aws

# Copy private key
echo "${private_key}"  > /home/ec2-user/.ssh/id_rsa 
sudo chmod 400 /home/ec2-user/.ssh/id_rsa
sudo chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa

# create an ansible variable file
echo "NEXUS_IP: ${nexus_ip}:8085"  > /etc/ansible/ansible_variable.yml

# Fetch Ansible playbooks from S3 bucket
s3_bucket_name="${s3_bucket_name}"
aws s3 cp s3://"${s3_bucket_name}"/scripts /etc/ansible/ --recursive
sudo chown -R ec2-user:ec2-user /etc/ansible/

echo "* * * * * ec2-user sh /etc/ansible/stage_bashscript.sh" > /etc/crontab
echo "* * * * * ec2-user sh /etc/ansible/prod_bashscript.sh" >> /etc/crontab


# Install New Relic
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${newrelic_api_key}" NEW_RELIC_ACCOUNT_ID="${newrelic_account_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y

sudo hostnamectl set-hostname ansible
