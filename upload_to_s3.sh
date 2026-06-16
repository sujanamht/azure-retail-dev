#!/bin/bash
# ============================================================
# Script: upload_to_s3.sh
# Purpose: Upload retail CSV files to AWS S3 bucket
# Bucket: s3://retail-sales-data
# ============================================================

set -e

BUCKET_NAME="retail-sales-data"
S3_PREFIX="raw/sales"         # Folder structure inside the bucket
LOCAL_DIR="./csv_files"       # Local directory containing CSV files

# --- Verify AWS CLI is installed ---
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not found. Install it with:"
    echo "  pip install awscli  OR  brew install awscli"
    exit 1
fi

# --- Check credentials are configured ---
echo "Verifying AWS credentials..."
aws sts get-caller-identity --query "Account" --output text > /dev/null 2>&1 || {
    echo "ERROR: AWS credentials not configured. Run: aws configure"
    exit 1
}
echo "✅ AWS credentials verified."

# --- Create S3 bucket if it doesn't exist ---
echo ""
echo "Checking if bucket '$BUCKET_NAME' exists..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ Bucket already exists."
else
    echo "Creating bucket '$BUCKET_NAME'..."
    # Note: us-east-1 does NOT use --create-bucket-configuration
    # Change region below if needed
    REGION="us-east-1"
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo "✅ Bucket '$BUCKET_NAME' created in region $REGION."
fi

# --- Upload CSV files ---
echo ""
echo "Uploading CSV files to s3://$BUCKET_NAME/$S3_PREFIX/ ..."
echo "-----------------------------------------------------------"

FILES=("sales_data.csv" "customer_data.csv" "product_data.csv")

for FILE in "${FILES[@]}"; do
    LOCAL_PATH="$LOCAL_DIR/$FILE"
    S3_PATH="s3://$BUCKET_NAME/$S3_PREFIX/$FILE"

    if [ ! -f "$LOCAL_PATH" ]; then
        echo "❌ File not found: $LOCAL_PATH — skipping."
        continue
    fi

    aws s3 cp "$LOCAL_PATH" "$S3_PATH" \
        --content-type "text/csv" \
        --metadata "source=retail-pipeline,environment=dev,uploaded=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    echo "✅ Uploaded: $FILE → $S3_PATH"
done

# --- Verify uploads ---
echo ""
echo "Verifying files in S3..."
echo "-----------------------------------------------------------"
aws s3 ls "s3://$BUCKET_NAME/$S3_PREFIX/" --human-readable

echo ""
echo "============================================================"
echo "✅ Step 2 Complete — All files uploaded to S3!"
echo "   Bucket  : s3://$BUCKET_NAME"
echo "   S3 Path : s3://$BUCKET_NAME/$S3_PREFIX/"
echo ""
echo "Next Step  : Step 3 — Configure Linked Services in ADF"
echo "   Connect ADF to:"
echo "     • AWS S3   (source)"
echo "     • ADLS Gen2 stretaildev001sz (destination)"
echo "     • Azure SQL RetailDW"
echo "     • Key Vault (for secrets)"
echo "============================================================"
