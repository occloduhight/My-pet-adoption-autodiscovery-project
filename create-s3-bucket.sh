#!/bin/bash

# set variable for bucket-name
BUCKET_NAME="auto-discovery-odochi2025"
AWS_REGION="eu-west-3"
AWS_PROFILE="default"

# # create bucket

echo "🚀 Creating S3 bucket: $BUCKET_NAME in region: $AWS_REGION"

aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION" 

#  # enable versioning
echo "🔐 Enabling versioning on bucket: $BUCKET_NAME"
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  --versioning-configuration Status=Enabled


echo "Creating Vault and Jenkins Server"
cd vault-jenkins
terraform init 
terraform validate
terraform apply -auto-approve
