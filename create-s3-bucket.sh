#!/bin/bash

# set variable for bucket-name
BUCKET_NAME="auto-discovery-odo2025"
AWS_REGION="eu-west-3"
AWS_PROFILE="default"


# create bucket
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"

# enable versioning
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  --versioning-configuration Status=Enabled

echo "Creating Vault and Jenkins Server"
cd vault-jenkins
terraform init 
terraform validate
terraform apply -auto-approve