#!/bin/bash
# Cleanup script to remove all deployed resources

set -e

echo "========================================"
echo "  Todo App Cleanup Script"
echo "========================================"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Confirmation
print_warning "This will DELETE all AWS resources including EKS cluster, VPC, RDS, S3, etc."
print_warning "This action CANNOT be undone!"
echo ""
read -p "Type 'destroy-all' to confirm: " confirm

if [ "$confirm" != "destroy-all" ]; then
    print_info "Cleanup cancelled"
    exit 0
fi

echo ""

# Get AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=${AWS_REGION:-us-east-1}
export PROJECT_NAME="todo-app"

print_warning "Starting cleanup process..."
echo ""

# Step 1: Delete Kubernetes resources
print_info "Step 1: Deleting Kubernetes resources..."

kubectl delete namespace ${PROJECT_NAME} --ignore-not-found || true
kubectl delete namespace argocd --ignore-not-found || true

echo "Waiting for namespace deletion..."
sleep 10

# Step 2: Delete Terraform resources
print_info "Step 2: Deleting AWS infrastructure with Terraform..."

cd terraform

if [ -f "terraform.tfstate" ]; then
    print_warning "Destroying all AWS resources..."
    
    # Get list of resources to destroy
    terraform state list
    
    read -p "Confirm resource destruction (yes/no): " confirm
    
    if [ "$confirm" == "yes" ]; then
        terraform destroy
        print_info "Terraform destroy complete"
    else
        print_info "Terraform destroy cancelled"
    fi
else
    print_warning "No Terraform state found"
fi

cd ..
echo ""

# Step 3: Delete ECR repository
print_info "Step 3: Deleting ECR repository..."

aws ecr delete-repository \
    --repository-name ${PROJECT_NAME} \
    --force \
    --region $AWS_REGION \
    2>/dev/null || print_warning "ECR repository not found or already deleted"

echo ""

# Step 4: Clean up S3 buckets
print_info "Step 4: Deleting S3 buckets..."

# App data bucket
aws s3 rm s3://todo-app-data-${AWS_ACCOUNT_ID}/ --recursive 2>/dev/null || true
aws s3api delete-bucket --bucket todo-app-data-${AWS_ACCOUNT_ID} --region $AWS_REGION 2>/dev/null || print_warning "App data bucket not found"

# Terraform state bucket
aws s3 rm s3://todo-app-terraform-state-${AWS_ACCOUNT_ID}/ --recursive 2>/dev/null || true
aws s3api delete-bucket --bucket todo-app-terraform-state-${AWS_ACCOUNT_ID} --region $AWS_REGION 2>/dev/null || print_warning "Terraform state bucket not found"

echo ""

# Step 5: Delete DynamoDB tables
print_info "Step 5: Deleting DynamoDB tables..."

aws dynamodb delete-table --table-name todo-app-items --region $AWS_REGION 2>/dev/null || print_warning "DynamoDB table not found"
aws dynamodb delete-table --table-name todo-app-items-sessions --region $AWS_REGION 2>/dev/null || print_warning "DynamoDB sessions table not found"
aws dynamodb delete-table --table-name terraform-locks --region $AWS_REGION 2>/dev/null || print_warning "Terraform locks table not found"

echo ""

# Step 6: Clean local Terraform files
print_info "Step 6: Cleaning local Terraform files..."

cd terraform
rm -rf .terraform
rm -f .terraform.lock.hcl
rm -f terraform.tfstate
rm -f terraform.tfstate.backup
rm -f tfplan
print_info "Terraform cache cleaned"
cd ..

echo ""

print_info "========================================"
print_info "Cleanup Complete!"
print_info "========================================"
echo ""

print_warning "Summary of deleted resources:"
echo "- Kubernetes namespaces (todo-app, argocd)"
echo "- EKS cluster (todo-app-eks)"
echo "- VPC and networking"
echo "- EC2 instances in node groups"
echo "- IAM roles and policies"
echo "- ECR repository"
echo "- S3 buckets"
echo "- DynamoDB tables"
echo "- CloudWatch logs"
echo ""

print_info "To reinstall, run: ./deploy.sh"
