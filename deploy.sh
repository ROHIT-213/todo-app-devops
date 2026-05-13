#!/bin/bash
# Automated deployment script for Todo App on AWS EKS

set -e

echo "========================================"
echo "  Todo App Deployment Script"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
print_info "Checking prerequisites..."

command -v aws >/dev/null 2>&1 || { print_error "AWS CLI not installed"; exit 1; }
command -v terraform >/dev/null 2>&1 || { print_error "Terraform not installed"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { print_error "kubectl not installed"; exit 1; }
command -v docker >/dev/null 2>&1 || { print_error "Docker not installed"; exit 1; }
command -v helm >/dev/null 2>&1 || { print_error "Helm not installed"; exit 1; }

print_info "All prerequisites found!"
echo ""

# Get AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=${AWS_REGION:-ap-south-1}
export PROJECT_NAME="todo-app"

print_info "AWS Account ID: $AWS_ACCOUNT_ID"
print_info "AWS Region: $AWS_REGION"
echo ""

# Step 1: Terraform infrastructure
print_info "Step 1: Deploying AWS Infrastructure with Terraform..."

cd terraform

# Initialize Terraform
print_info "Initializing Terraform..."
terraform init

# Validate
print_info "Validating Terraform configuration..."
terraform validate

# Plan
print_info "Planning Terraform changes..."
terraform plan -out=tfplan

# Apply
read -p "Do you want to proceed with infrastructure deployment? (yes/no): " confirm
if [ "$confirm" == "yes" ]; then
    print_info "Applying Terraform changes... (this may take 15-20 minutes)"
    terraform apply tfplan
    print_info "Infrastructure deployment complete!"
    terraform output -json > ../terraform_outputs.json
else
    print_warning "Deployment cancelled by user"
    exit 0
fi

cd ..
echo ""

# Step 2: Configure kubectl
print_info "Step 2: Configuring kubectl..."

aws eks update-kubeconfig \
    --region $AWS_REGION \
    --name ${PROJECT_NAME}-eks

print_info "Waiting for cluster to be fully ready..."
sleep 30

# Verify connection
kubectl cluster-info
print_info "kubectl configured successfully!"
echo ""

# Step 3: Create namespace
print_info "Step 3: Creating Kubernetes namespace..."
kubectl apply -f k8s/namespace.yaml
print_info "Namespace created!"
echo ""

# Step 4: Create ECR repository
print_info "Step 4: Setting up Docker registry..."

REPO_NAME="${PROJECT_NAME}"
if ! aws ecr describe-repositories --repository-names $REPO_NAME --region $AWS_REGION 2>/dev/null; then
    print_info "Creating ECR repository..."
    aws ecr create-repository \
        --repository-name $REPO_NAME \
        --region $AWS_REGION
else
    print_warning "ECR repository already exists"
fi

# Login to ECR
print_info "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push image
print_info "Building Docker image..."
docker build -t $REPO_NAME:latest .

print_info "Tagging image for ECR..."
docker tag $REPO_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest
docker tag $REPO_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$(git rev-parse --short HEAD)

print_info "Pushing image to ECR..."
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$(git rev-parse --short HEAD)

print_info "Docker image pushed successfully!"
echo ""

# Step 5: Deploy Kubernetes manifests
print_info "Step 5: Deploying Kubernetes manifests..."

# Update deployment image
print_info "Updating deployment with correct image registry..."
sed -i "s|image: .*|image: rohit213/project-app:latest|g" k8s/deployment.yaml

# Apply manifests
print_info "Applying Kubernetes manifests..."
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

print_info "Waiting for deployment to be ready... (this may take 2-3 minutes)"
kubectl rollout status deployment/todo-app-deployment -n ${PROJECT_NAME} --timeout=5m

print_info "Kubernetes deployment complete!"
echo ""

# Step 6: Install ArgoCD
print_info "Step 6: Installing ArgoCD..."

# Create ArgoCD namespace
kubectl create namespace argocd || true

# Add Helm repo
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

# Install ArgoCD
print_info "Installing ArgoCD via Helm..."
helm install argocd argo/argo-cd \
    --namespace argocd \
    --set server.service.type=LoadBalancer \
    --set server.insecure=true \
    --wait || true

print_info "ArgoCD installed!"
echo ""

# Step 7: Get access information
print_info "Step 7: Retrieving access information..."

echo ""
print_info "========================================"
print_info "Deployment Complete!"
print_info "========================================"
echo ""

# Application URL
print_info "Application Access:"
echo "Waiting for LoadBalancer IP..."
sleep 5

APP_LB=$(kubectl get svc todo-app-service -n ${PROJECT_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
if [ "$APP_LB" != "pending" ]; then
    echo "URL: http://$APP_LB"
else
    echo "URL: Still provisioning, check with: kubectl get svc -n ${PROJECT_NAME}"
fi

echo ""

# ArgoCD access
print_info "ArgoCD Access:"
ARGOCD_LB=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
if [ "$ARGOCD_LB" != "pending" ]; then
    echo "URL: https://$ARGOCD_LB"
else
    echo "URL: Still provisioning, check with: kubectl get svc -n argocd"
fi

# ArgoCD password
print_info "ArgoCD Admin Password:"
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
echo "Username: admin"
echo "Password: $ARGOCD_PASS"

echo ""
print_info "Next Steps:"
echo "1. Update your GitHub credentials in ArgoCD"
echo "2. Create ArgoCD Application: kubectl apply -f argocd/application.yaml"
echo "3. Configure CircleCI with GitHub repository"
echo "4. Push code changes to trigger CI/CD pipeline"
echo ""

print_info "Useful Commands:"
echo "kubectl get pods -n ${PROJECT_NAME}              # Check application pods"
echo "kubectl logs -f deployment/todo-app-deployment -n ${PROJECT_NAME}  # View logs"
echo "kubectl get svc -n ${PROJECT_NAME}              # Get application URL"
echo "kubectl get svc -n argocd                        # Get ArgoCD URL"
echo "argocd app list                                   # List ArgoCD applications"
echo "terraform output                                  # View infrastructure outputs"
echo ""

print_info "Documentation:"
echo "README.md            - Project overview"
echo "SETUP.md             - Detailed setup guide"
echo "DEPLOYMENT.md        - Deployment strategies"
echo "TROUBLESHOOTING.md   - Common issues and solutions"
echo ""
