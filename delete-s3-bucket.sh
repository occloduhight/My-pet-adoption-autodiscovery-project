#!/bin/bash
BUCKET_NAME="auto-discovery-odo2025"
AWS_REGION="eu-west-3"
AWS_PROFILE="default"
cd vault-jenkins
# Destroy Vault and Jenkins infrastructure using Terraform
if ! terraform destroy --auto-approve; then
    rc=$?
    echo "ERROR: terraform destroy failed with exit code $rc" >&2
    # return to parent dir before exiting so environment is sane for the caller
    cd ..
    exit $rc
fi

# List and delete all object versions in the bucket
VERSIONS=$(aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --output json)

# Delete all objects and their versions
echo "$VERSIONS" | jq -c '.Versions[]' | while read -r version; do
    KEY=$(echo "$version" | jq -r '.Key')
    VERSION_ID=$(echo "$version" | jq -r '.VersionId') 
    aws s3api delete-object \
        --bucket $BUCKET_NAME \
        --key "$KEY" \
        --version-id "$VERSION_ID" \
        --profile $AWS_PROFILE \
        --region $AWS_REGION
done
echo "$VERSIONS" | jq -c '.DeleteMarkers[]' | while read -r marker; do
    KEY=$(echo "$marker" | jq -r '.Key')
    VERSION_ID=$(echo "$marker" | jq -r '.VersionId') 
    aws s3api delete-object \
        --bucket $BUCKET_NAME \
        --key "$KEY" \
        --version-id "$VERSION_ID" \
        --profile $AWS_PROFILE \
        --region $AWS_REGION
done    

# Delete the S3 bucket
aws s3api delete-bucket \
    --bucket $BUCKET_NAME \
    --profile $AWS_PROFILE \
    --region $AWS_REGION   
echo "Bucket $BUCKET_NAME and all its contents have been deleted."