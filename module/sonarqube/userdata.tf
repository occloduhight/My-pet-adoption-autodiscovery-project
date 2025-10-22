locals {
userdata = <<EOF
#!/bin/bash
sudo apt update -y
echo "***Firstly Modify OS Level values***"
sudo bash -c 'echo "
vm.max_map_count=262144
fs.file-max=65536
ulimit -n 65536
ulimit -u 4096" >> /etc/sysctl.conf'
sudo bash -c 'echo "
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096" >> /etc/security/limits.conf'
echo "***********Install Java JDK***********"
sudo apt install openjdk-11-jdk -y
echo "***********Install PostgreSQL***********"
echo "***********The version of postgres currenlty is 14.5 which is not supported so we have to download v12***********"
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update -y
sudo apt-get -y install postgresql-12 postgresql-contrib-12
echo "*****Enable and start, so it starts when system boots up*******"
sudo systemctl enable postgresql
sudo systemctl start postgresql
#Change default password of postgres user
sudo chpasswd <<<"postgres:Admin123@"
#Create user sonar without switching technically
sudo su -c 'createuser sonar' postgres
#Create SonarQube Database and change sonar password
sudo su -c "psql -c \"ALTER USER sonar WITH ENCRYPTED PASSWORD 'Admin123'\"" postgres
sudo su -c "psql -c \"CREATE DATABASE sonarqube OWNER sonar\"" postgres
sudo su -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE sonarqube to sonar\"" postgres
#Restart postgresql for changes to take effect
sudo systemctl restart postgresql
#Install SonarQube
sudo mkdir /sonarqube/
cd /sonarqube/
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-8.6.0.39681.zip
sudo apt install unzip -y
sudo unzip sonarqube-8.6.0.39681.zip -d /opt/
sudo mv /opt/sonarqube-8.6.0.39681/ /opt/sonarqube
#Add group user sonarqube
sudo groupadd sonar
#Then, create a user and add the user into the group with directory permission to the /opt/ directory
sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
#Change ownership of the directory to sonar
sudo chown sonar:sonar /opt/sonarqube/ -R
sudo bash -c 'echo "
sonar.jdbc.username=sonar
sonar.jdbc.password=Admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError" >> /opt/sonarqube/conf/sonar.properties'
 #Configure such that SonarQube starts on boot up
sudo touch /etc/systemd/system/sonarqube.service
#Configuring so that we can run commands to start, stop and reload sonarqube service
sudo bash -c 'echo "
[Unit]
Description=SonarQube service
After=syslog.target network.target
[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
ExecReload=/opt/sonarqube/bin/linux-x86-64/sonar.sh restart
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096
[Install]
WantedBy=multi-user.target" >> /etc/systemd/system/sonarqube.service'
#Enable and Start the Service
sudo systemctl daemon-reload
sudo systemctl enable sonarqube.service
sudo systemctl start sonarqube.service
#Install net-tools incase we want to debug later
sudo apt install net-tools -y
#Install nginx
sudo apt-get install nginx -y
#Configure nginx so we can access server from outside
sudo touch /etc/nginx/sites-enabled/sonarqube.conf
sudo bash -c 'echo "
server {
  listen 80;
  access_log  /var/log/nginx/sonar.access.log;
  error_log   /var/log/nginx/sonar.error.log;
  proxy_buffers 16 64k;
  proxy_buffer_size 128k;
  location / {
      proxy_pass  http://127.0.0.1:9000;
      proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
      proxy_redirect off;
      proxy_set_header    Host            \$host;
      proxy_set_header    X-Real-IP       \$remote_addr;
      proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header    X-Forwarded-Proto http;
  }
}" >> /etc/nginx/sites-enabled/sonarqube.conf'
#Remove the default configuration file
sudo rm /etc/nginx/sites-enabled/default
#Enable and restart nginix service
sudo systemctl enable nginx.service
sudo systemctl stop nginx.service
sudo systemctl start nginx.service
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY=${var.nr_key} NEW_RELIC_ACCOUNT_ID=${var.nr_id} /usr/local/bin/newrelic install -y
sudo hostnamectl set-hostname Sonarqube
sudo reboot
EOF
}