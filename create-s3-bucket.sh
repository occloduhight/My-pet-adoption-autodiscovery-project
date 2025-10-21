# #!/bin/bash

# # set variable for bucket-name
# BUCKET_NAME="auto-discovery-odo2025"
# AWS_REGION="eu-west-3"
# AWS_PROFILE="default"

# # # create bucket

# echo "🚀 Creating S3 bucket: $BUCKET_NAME in region: $AWS_REGION"

# aws s3api create-bucket \
#   --bucket "$BUCKET_NAME" \
#   --region "$AWS_REGION" \
#   --profile "$AWS_PROFILE" \
#   --create-bucket-configuration LocationConstraint="$AWS_REGION" 

# #  # enable versioning
# echo "🔐 Enabling versioning on bucket: $BUCKET_NAME"
# aws s3api put-bucket-versioning \
#   --bucket "$BUCKET_NAME" \
#   --region "$AWS_REGION" \
#   --profile "$AWS_PROFILE" \
#   --versioning-configuration Status=Enabled


# echo "Creating Vault and Jenkins Server"
# cd vault-jenkins
# terraform init 
# terraform validate
# terraform apply -auto-approve

#!/bin/bash

# 🚀 Variables
BUCKET_NAME="auto-discovery-odo2025"   # change to your new bucket name
AWS_REGION="eu-west-3"
AWS_PROFILE="default"

# ✅ Function to check if bucket exists
function bucket_exists() {
    aws s3api head-bucket --bucket "$1" --profile "$AWS_PROFILE" 2>/dev/null
}

# 1️⃣ Create S3 bucket if it doesn't exist
if bucket_exists "$BUCKET_NAME"; then
    echo "Bucket $BUCKET_NAME already exists."
else
    echo "Creating S3 bucket: $BUCKET_NAME in region: $AWS_REGION..."
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"

    echo "Enabling versioning on bucket: $BUCKET_NAME..."
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --versioning-configuration Status=Enabled

        # Wait a few seconds for bucket propagation
    sleep 2
fi

# 2️⃣ Initialize and apply Terraform
echo "Initializing and applying Terraform..."
cd vault-jenkins || exit
terraform init
terraform validate
terraform apply -auto-approve
