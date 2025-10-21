# #!/bin/bash

# echo "deleting jenkins and vault server"
# cd vault-jenkins
# terraform init 
# terraform destroy -auto-approve

# echo "creating S3 bucket"

# # Using the same variables as ones used for creation
# BUCKET_NAME="auto-discovery-odo2025"
# AWS_REGION="eu-west-3"


# echo "Deleting all objects in $BUCKET_NAME. This process is irreversible..."

# # List all object versions and delete markers
# DELETE_LIST=$(aws s3api list-object-versions \
#   --bucket "$BUCKET_NAME" \
#   --profile "$AWS_PROFILE" \
#   --region "$AWS_REGION" \
#   --output json)

# # Extract objects to delete using jq and set as a variable
# OBJECTS_TO_DELETE=$(echo "$DELETE_LIST" | jq '{
#   Objects: (
#     [.Versions[]?, .DeleteMarkers[]?]
#     | map({Key: .Key, VersionId: .VersionId})
#   ),
#   Quiet: true
# }')

# # Count number of deletable items and set as a variable
# NUM_OBJECTS=$(echo "$OBJECTS_TO_DELETE" | jq '.Objects | length')

# # Delete objects if there are any
# if [ "$NUM_OBJECTS" -gt 0 ]; then
#   echo "Deleting $NUM_OBJECTS objects from bucket: $BUCKET_NAME..."
#   aws s3api delete-objects \
#     --bucket "$BUCKET_NAME" \
#     --delete "$OBJECTS_TO_DELETE" \
#     --region "$AWS_REGION" \
#     --profile "$AWS_PROFILE"
#   echo "Object deletion complete."
# else
#   echo "No objects or versions found in $BUCKET_NAME."
# fi

# # Attempt to delete the empty bucket
# echo "Deleting bucket: $BUCKET_NAME..."
# aws s3api delete-bucket \
#   --bucket "$BUCKET_NAME" \
#   --region "$AWS_REGION" \
#   --profile "$AWS_PROFILE"

# echo "Bucket $BUCKET_NAME deleted successfully."

#!/bin/bash

# 🚀 Variables
BUCKET_NAME="auto-discovery-odo2025"
AWS_REGION="eu-west-3"
AWS_PROFILE="default"

# 1️⃣ Destroy Terraform-managed resources
echo "Deleting Jenkins and Vault servers..."
cd vault-jenkins || exit
terraform init
terraform destroy -auto-approve
cd - || exit

# 2️⃣ Check if the bucket exists
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
    echo "Bucket $BUCKET_NAME does not exist. Skipping deletion."
    exit 0
fi

# 3️⃣ Delete all objects and versions in the bucket
echo "Deleting all objects in bucket: $BUCKET_NAME..."
DELETE_LIST=$(aws s3api list-object-versions \
    --bucket "$BUCKET_NAME" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --output json)

OBJECTS_TO_DELETE=$(echo "$DELETE_LIST" | jq '{
  Objects: ([.Versions[]?, .DeleteMarkers[]?] | map({Key: .Key, VersionId: .VersionId})),
  Quiet: true
}')

NUM_OBJECTS=$(echo "$OBJECTS_TO_DELETE" | jq '.Objects | length')

if [ "$NUM_OBJECTS" -gt 0 ]; then
    echo "Deleting $NUM_OBJECTS objects..."
    aws s3api delete-objects \
        --bucket "$BUCKET_NAME" \
        --delete "$OBJECTS_TO_DELETE" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
    echo "Objects deleted."
else
    echo "No objects found in bucket."
fi

# 4️⃣ Delete the bucket itself
echo "Deleting bucket: $BUCKET_NAME..."
aws s3api delete-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE"

echo "Bucket $BUCKET_NAME deleted successfully."
