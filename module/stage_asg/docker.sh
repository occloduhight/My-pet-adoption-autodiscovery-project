#!/bin/bash
sudo yum update -y
sudo yum upgrade -y
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
sudo hostnamectl set-hostname stage-asg
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${nr_key}" NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -yc:\Users\chinw\Desktop\AUTODISCPROJECT\module\prod_asg