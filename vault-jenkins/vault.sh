#!/bin/bash
set -e

# Update OS
sudo apt update -y
sudo apt install -y unzip wget jq
# Install Vault
VAULT_VERSION=""1.18.3""
# Download Vault binary
wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
# Unzip the Vault binary and move it to /usr/local/bin
unzip vault_${VAULT_VERSION}_linux_amd64.zip
# Move it to /usr/local/bin
sudo mv vault /usr/local/bin/
# print the version of Vault installed on the system.
vault -v
# Set ownership and permissions
sudo chown root:root /usr/local/bin/vault
sudo chmod 0755 /usr/local/bin/vault
# Create Vault user and folders
sudo useradd --system --home /etc/vault.d --shell /bin/false vault
sudo mkdir -p /etc/vault.d /opt/vault/data
sudo mkdir -p /var/lib/vault                       # p = parents
sudo chown -R vault:vault /etc/vault.d /opt/vault  # R = recursive
# Create Vault configuration file
cat <<EOF | sudo tee /etc/vault.d/vault.hcl
ui = true
storage "file" {
  path = "/opt/vault/data"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
}
api_addr = "http://0.0.0.0:8200"
seal "awskms" {
    region = "${region}"
    kms_key_id = "${key}"
}
EOF
# Set permissions for the configuration file
sudo chown vault:vault /etc/vault.d/vault.hcl
sudo chmod 640 /etc/vault.d/vault.hcl
# Create systemd service file for Vault
at <<EOF | sudo tee /etc/systemd/system/vault.service
[Unit]
Description=HashiCorp Vault
After=network.target

[Service]
User=vault
Group=vault
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
# Reload systemd to recognize the new service
sudo systemctl daemon-reload
# Wait for Vault to start
sleep 5
# create a variable for the vault URL
export VAULT_ADDR='http://localhost:8200'
cat <<EOT > /etc/profile.d/vault.sh
export VAULT_ADDR='http://localhost:8200'
export VAULT_SKIP_VERIFY=true
EOT
# Enable and start the Vault service
sudo systemctl enable vault
sudo systemctl start vault
sleep 10
export VAULT_ADDR='http://127.0.0.1:8200'
# Initialize Vault
touch /home/ubuntu/vault_init.log
vault operator init > /home/ubuntu/vault_init.log
grep -o 'hvs\.[A-Za-z0-9]\{24\}' /home/ubuntu/vault_init.log > /home/ubuntu/token.txt
TOKEN=$(</home/ubuntu/token.txt)
# Login to Vault
vault login $TOKEN
# Enable KV secrets engine
vault secrets enable -path=secret kv-v2  #directory to store secrets on the vault server

# Store database credentials in Vault
vault kv put secret/database \
  username="db_admin" \
  password="admin123" \
# Set hostname to Vault
  sudo hostnamectl set-hostname Vault

echo "Vault installation complete!"
echo "Database credentials stored in Vault path: secret/database"
