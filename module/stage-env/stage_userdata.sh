#!/bin/bash
 
#updatng the instance
sudo yum update -y
sudo yum upgrade -y

#install Docker and its dependencies, start Docker service
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo #downloads & adds repo to instance
sudo yum install docker-ce -y
 
#add a registry to the Docker daemon configuration to allow 
#insecure communication (without TLS verification) with a Docker registry on port 8085
sudo cat <<EOT>> /etc/docker/daemon.json
  {
    "insecure-registries" : ["${nexus_ip}:8085"]
  }
EOT
 
#Starts the Docker service and enables it to run on boot.
#Add the ec2-user to the docker group, allowing them to run Docker commands.
sudo service docker start
sudo systemctl start docker
sudo systemctl enable docker

#add the ec2-user to the docker group, allowing them to run Docker commands.
sudo usermod -aG docker ec2-user
sudo chmod 777 /var/run/docker.sock

#Restart Docker
sudo systemctl restart docker

# Install New Relic agent
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${nr_key}" NEW_RELIC_ACCOUNT_ID="${nr_acct_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y

# Set hostname
sudo hostnamectl set-hostname stage