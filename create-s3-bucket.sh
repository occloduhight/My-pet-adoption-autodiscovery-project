#!/bin/bash

# set variable for bucket-name
BUCKET_NAME="auto-discovery-odo2025"
AWS_REGION="eu-west-3"
AWS_PROFILE="default"


# Create S3 bucket
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $AWS_REGION \
    --create-bucket-configuration LocationConstraint=$AWS_REGION \
    --profile $AWS_PROFILE

# Enable versioning on the bucket
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled \
    --profile $AWS_PROFILE \
    --region $AWS_REGION

echo "Bucket $BUCKET_NAME created with versioning enabled in region $AWS_REGION."


echo "Creating Vault and Jenkins infrastructure using Terraform..."
cd vault-jenkins
terraform init
terraform apply --auto-approve