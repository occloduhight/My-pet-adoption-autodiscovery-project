#!/bin/bash

# Script configuration variables
ASG_NAME="petclinic2-stage-asg"               # Auto Scaling Group name
REGION="us-east-1"                 # AWS region
INVENTORY_FILE="/etc/ansible/stage_hosts"       # Ansible inventory file
IP_LIST_FILE="/etc/ansible/stage_ips.txt"  # Temporary file to store discovered IPs
SSH_USER="ec2-user"               # SSH user for RedHat instances
SSH_KEY_PATH="/home/ec2-user/.ssh/id_rsa"  # Path to SSH private key
DOCKER_REPO="nexus.work-experience2025.buzz"    # Nexus Docker repository URL
DOCKER_USER="admin"        # Docker repository username
DOCKER_PASSWORD="admin123"    # Docker repository password
APP_IMAGE="$DOCKER_REPO/nexus-docker-repo/apppetclinic:latest"        # Docker image name and tag

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required commands
for cmd in aws ssh ssh-keyscan; do
    if ! command_exists "$cmd"; then
        log_message "Error: Required command '$cmd' is not installed."
        exit 1
    fi
done

# Clean up function
cleanup() {
    if [[ -f "$IP_LIST_FILE" ]]; then
        rm -f "$IP_LIST_FILE"
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Create/clear the IP list file
> "$IP_LIST_FILE"

log_message "Starting EC2 instance discovery in Auto Scaling Group: $ASG_NAME"

# Get instance IPs from Auto Scaling Group
instance_ids=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-name "$ASG_NAME" \
    --region "$REGION" \
    --query 'AutoScalingGroups[*].Instances[*].InstanceId' \
    --output text)

# Check if we got any instances
if [[ -z "$instance_ids" ]]; then
    log_message "Error: No instances found in Auto Scaling Group"
    exit 1
fi

# Get all private IPs in one call
log_message "Found instances, retrieving private IPs..."
aws ec2 describe-instances \
    --instance-ids $instance_ids \
    --region "$REGION" \
    --query 'Reservations[*].Instances[*].PrivateIpAddress' \
    --output text | while read -r private_ip; do
    if [[ -n "$private_ip" ]]; then
        echo "$private_ip" >> "$IP_LIST_FILE"
        log_message "Discovered instance IP: $private_ip"
    fi
done

# Verify we got all IPs
discovered_count=$(wc -l < "$IP_LIST_FILE")
expected_count=$(echo "$instance_ids" | wc -w)
log_message "Discovered $discovered_count private IPs out of $expected_count instances"

# Check if we found any IPs
if [[ ! -s "$IP_LIST_FILE" ]]; then
    log_message "Error: No instances found in Auto Scaling Group"
    exit 1
fi

# Update Ansible inventory file
log_message "Updating Ansible inventory file: $INVENTORY_FILE"
echo "[webservers]" > "$INVENTORY_FILE"
cat "$IP_LIST_FILE" >> "$INVENTORY_FILE"

# Add hosts to known_hosts file
log_message "Adding hosts to SSH known_hosts file"
while read -r ip; do
    ssh-keyscan -H "$ip" >> ~/.ssh/known_hosts 2>/dev/null
    log_message "Added $ip to known_hosts"
done < "$IP_LIST_FILE"

# Function to process a single instance
process_instance() {
    local ip=$1
    local exit_status=0
    
    log_message "Connecting to $ip"
    
    # Check if Docker container is running
    container_running=$(ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 "$SSH_USER@$ip" \
        "docker ps --filter name=appContainer --format '{{.Names}}' 2>/dev/null")
    
    if [[ -z "$container_running" ]]; then
        log_message "Container 'appContainer' not found on $ip. Deploying..."
        
        # Execute Docker commands remotely with timeout
        ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 "$SSH_USER@$ip" << EOF
            # Docker login
            echo "$DOCKER_PASSWORD" | docker login $DOCKER_REPO -u "$DOCKER_USER" --password-stdin || exit 1
            
            # Pull latest image with timeout
            timeout 300 docker pull $APP_IMAGE || exit 1
            
            # Check for existing container and remove if stopped
            if docker ps -a | grep -q appContainer; then
                docker rm -f appContainer >/dev/null 2>&1
            fi
            
            # Run container
            docker run -d --name appContainer -p 8080:8080 --restart unless-stopped $APP_IMAGE || exit 1
            
            # Verify container is running
            if docker ps | grep -q appContainer; then
                echo "Container deployed successfully"
            else
                echo "Failed to deploy container"
                exit 1
            fi
EOF
        
        if [[ $? -eq 0 ]]; then
            log_message "Successfully deployed container on $ip"
        else
            log_message "Error: Failed to deploy container on $ip"
            exit_status=1
        fi
    else
        log_message "Container 'appContainer' is already running on $ip"
    fi
    
    return $exit_status
}

# Check Docker container and deploy if needed
log_message "Checking Docker containers on all instances"
declare -A pids
failures=0

# Process instances in parallel with a maximum of 5 concurrent jobs
max_parallel=5
count=0

while read -r ip; do
    # Wait if we've reached max parallel jobs
    while [[ $(jobs -p | wc -l) -ge $max_parallel ]]; do
        sleep 1
    done
    
    # Process instance in background
    process_instance "$ip" &
    pids["$ip"]=$!
    
    count=$((count + 1))
    log_message "Started processing instance $ip (PID: ${pids[$ip]})"
done < "$IP_LIST_FILE"

# Wait for all background jobs to complete
for ip in "${!pids[@]}"; do
    if wait "${pids[$ip]}"; then
        log_message "Successfully completed processing instance $ip"
    else
        log_message "Failed processing instance $ip"
        failures=$((failures + 1))
    fi
done

if [[ $failures -gt 0 ]]; then
    log_message "Warning: $failures instance(s) failed processing"
fi

log_message "Script execution completed successfully"