locals {
  ansible_userdata = <<-EOF
#!/bin/bash

# updating instance
sudo yum update -y
sudo yum install wget unzip -y
sudo bash -c 'echo "StrictHostKeyChecking No" >> /etc/ssh/ssh_config'

# Installing awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo ln -svf /usr/local/bin/aws /usr/bin/aws

# installing ansible
sudo dnf install -y ansible-core
sudo yum update -y

# Copy private key into ansible server /home/ec2-user/.ssh/ dir.
sudo echo "${var.private_key}" > /home/ec2-user/.ssh/id_rsa

#Give permission to copied file
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
sudo chmod 400 /home/ec2-user/.ssh/id_rsa

# pull scripts from S3 bucket
aws s3 cp s3://pet-adoption-set25/ansible-scripts/prod-bashscript.sh /etc/ansible/prod-bashscript.sh
aws s3 cp s3://pet-adoption-set25/ansible-scripts/stage-bashscript.sh /etc/ansible/stage-bashscript.sh
aws s3 cp s3://pet-adoption-set25/ansible-scripts/deployment.yml /etc/ansible/deployment.yml

# create ansible variable file
sudo bash -c 'echo "NEXUS_IP: ${var.nexus_ip}:8085" > /etc/ansible/ansible_vars_file.yml'
sudo chown -R ec2-user:ec2-user /etc/ansible
sudo chmod 755 /etc/ansible/prod-bashscript.sh
sudo chmod 755 /etc/ansible/stage-bashscript.sh

# Creating cron job using our bash script
echo "* * * * * ec2-user sh /etc/ansible/prod-bashscript.sh" > /etc/crontab
echo "* * * * * ec2-user sh /etc/ansible/stage-bashscript.sh" >> /etc/crontab

# Install New Relic
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${var.nr_key}" NEW_RELIC_ACCOUNT_ID="${var.nr_acc_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y
sudo hostnamectl set-hostname ansible-server
EOF
}