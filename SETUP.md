# Setup & Deployment Guide

## Prerequisites

Before starting, ensure you have the following installed and configured:

### 1. AWS CLI

```bash
# Install AWS CLI v2
# Windows: https://awscli.amazonaws.com/AWSCLIV2.msi

# Verify installation
aws --version

# Configure credentials
aws configure
# Enter Access Key ID
# Enter Secret Access Key
# Enter Default region (us-east-1)
# Enter Default output format (json)
```

### 2. Terraform

```bash
# Install Terraform
# Download from: https://www.terraform.io/downloads.html

# Verify installation
terraform --version
```

### 3. kubectl

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client
```

### 4. Docker

```bash
# Install Docker Desktop
# Windows: https://www.docker.com/products/docker-desktop

# Verify installation
docker --version
```

### 5. Git

```bash
# Install Git
# Windows: https://git-scm.com/download/win

# Configure git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify installation
git --version
```

### 6. Helm (Optional but recommended)

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

## Step-by-Step Setup

### Phase 1: Prepare AWS Environment

#### 1.1 Verify AWS Credentials

```bash
# Test AWS access
aws sts get-caller-identity

# Output should show your Account ID, User ARN, etc.
```

#### 1.2 Create S3 Bucket for Terraform State

```bash
# Set variables
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1
export STATE_BUCKET_NAME="todo-app-terraform-state-${AWS_ACCOUNT_ID}"

# Create S3 bucket
aws s3api create-bucket \
  --bucket $STATE_BUCKET_NAME \
  --region $AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $STATE_BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $STATE_BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $STATE_BUCKET_NAME \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Terraform state bucket created: $STATE_BUCKET_NAME"
```

#### 1.3 Create DynamoDB Table for State Locking

```bash
# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION

echo "DynamoDB locking table created: terraform-locks"
```

### Phase 2: Configure Terraform

#### 2.1 Update Terraform Backend Configuration

Edit `terraform/provider.tf` and update the S3 bucket name:

```hcl
backend "s3" {
  bucket         = "todo-app-terraform-state-YOUR_ACCOUNT_ID"
  key            = "eks/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

#### 2.2 Create terraform.tfvars

```bash
cd terraform

# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your preferences
# vim terraform.tfvars
```

Example `terraform.tfvars`:

```hcl
aws_region = "us-east-1"
environment = "production"
project_name = "todo-app"

vpc_cidr = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

cluster_name = "todo-app-eks"
cluster_version = "1.27"
node_group_desired_size = 3
node_group_min_size = 3
node_group_max_size = 10
node_instance_types = ["t3.medium"]

enable_argocd = true
enable_monitoring = true

container_registry = "docker.io"

dynamodb_table_name = "todo-app-items"
s3_bucket_name = "todo-app-data"
```

#### 2.3 Initialize Terraform

```bash
cd terraform

# Initialize Terraform (downloads providers, sets up backend)
terraform init

# Output should show successful initialization
# Terraform has been successfully configured!
```

#### 2.4 Validate Terraform Configuration

```bash
# Validate syntax
terraform validate

# Output should show: Success! The configuration is valid.
```

#### 2.5 Plan Terraform Changes

```bash
# Create execution plan (review what will be created)
terraform plan -out=tfplan

# Review the output - should show:
# - 1 VPC
# - 3 Subnets (public) + 3 Subnets (private)
# - 1 EKS Cluster
# - 1 Node Group
# - IAM roles and policies
# - DynamoDB tables
# - S3 buckets
# - etc.
```

### Phase 3: Deploy AWS Infrastructure

⚠️ **WARNING**: This will create AWS resources and may incur charges. Review the plan carefully.

#### 3.1 Apply Terraform Changes

```bash
# Apply the planned changes
terraform apply tfplan

# This will take 15-20 minutes to complete
# Wait for completion message:
# Apply complete! Resources: XX added, 0 changed, 0 destroyed.
```

#### 3.2 Save Terraform Outputs

```bash
# Export outputs for later use
terraform output -json > ../terraform_outputs.json

# View key outputs
terraform output eks_cluster_name
terraform output eks_cluster_endpoint
terraform output configure_kubectl
```

### Phase 4: Configure kubectl

#### 4.1 Update kubeconfig

```bash
# Configure kubectl to access EKS cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name todo-app-eks

# Verify connection
kubectl get nodes

# Output should show 3 nodes in Ready state
```

#### 4.2 Verify Cluster Access

```bash
# Get cluster info
kubectl cluster-info

# Get nodes with more details
kubectl get nodes -o wide

# Get current context
kubectl config current-context
```

### Phase 5: Setup Container Registry (ECR)

#### 5.1 Create ECR Repository

```bash
# Create repository for Docker images
aws ecr create-repository \
  --repository-name todo-app \
  --region us-east-1

# Output will show repository details including URI
```

#### 5.2 Login to ECR

```bash
# Get ECR login credentials
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com

# Output should show: Login Succeeded
```

#### 5.3 Build and Push Docker Image

```bash
# Navigate to project root
cd /path/to/todo-app

# Build Docker image
docker build -t todo-app:latest .

# Tag image for ECR
export ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
docker tag todo-app:latest $ECR_REGISTRY/todo-app:latest
docker tag todo-app:latest $ECR_REGISTRY/todo-app:$(git rev-parse --short HEAD)

# Push to ECR
docker push $ECR_REGISTRY/todo-app:latest
docker push $ECR_REGISTRY/todo-app:$(git rev-parse --short HEAD)

# Verify image in ECR
aws ecr describe-images --repository-name todo-app --region us-east-1
```

### Phase 6: Deploy Kubernetes Manifests

#### 6.1 Create Namespace

```bash
# Create todo-app namespace
kubectl create namespace todo-app

# Verify namespace
kubectl get namespaces
```

#### 6.2 Update Deployment Manifest

Update `k8s/deployment.yaml` with your ECR registry:

```yaml
# Replace this line:
image: your-registry/todo-app:latest

# With your actual ECR registry:
image: YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/todo-app:latest
```

#### 6.3 Apply Kubernetes Manifests

```bash
# Apply manifests in order
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

# Alternatively, apply all at once
kubectl apply -f k8s/

# Verify deployments
kubectl get deployments -n todo-app
kubectl get pods -n todo-app
kubectl get svc -n todo-app
```

#### 6.4 Wait for Deployment to Be Ready

```bash
# Wait for rollout to complete
kubectl rollout status deployment/todo-app-deployment -n todo-app --timeout=5m

# Check pod status
kubectl get pods -n todo-app -w

# View pod details
kubectl describe pod <pod-name> -n todo-app

# View application logs
kubectl logs -f <pod-name> -n todo-app -c todo-app
```

#### 6.5 Access the Application

```bash
# Get LoadBalancer external IP
kubectl get svc -n todo-app

# Wait for EXTERNAL-IP to be assigned (may take 2-3 minutes)

# Access application in browser:
# http://<EXTERNAL-IP>

# Port forward alternative (if external IP not available)
kubectl port-forward svc/todo-app-service -n todo-app 8080:80
# Then access: http://localhost:8080
```

### Phase 7: Install ArgoCD

#### 7.1 Create ArgoCD Namespace

```bash
# Create namespace
kubectl create namespace argocd

# Verify
kubectl get namespaces
```

#### 7.2 Install ArgoCD

```bash
# Add Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=LoadBalancer \
  --set server.insecure=true \
  --set redis.enabled=true \
  --set applicationSet.enabled=true \
  --set notifications.enabled=true \
  --wait

# Verify installation
kubectl get pods -n argocd
```

#### 7.3 Get ArgoCD Admin Password

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# Output: initial-password
```

#### 7.4 Access ArgoCD UI

```bash
# Get LoadBalancer IP (may take 1-2 minutes)
kubectl get svc -n argocd

# Access ArgoCD:
# https://EXTERNAL-IP
# Username: admin
# Password: (from above)

# Alternative: Port forward
kubectl port-forward svc/argocd-server -n argocd 8443:443
# Access: https://localhost:8443
```

### Phase 8: Configure ArgoCD

#### 8.1 Create GitHub Credentials Secret

Edit `argocd/github-secret.yaml` with your GitHub details:

```yaml
stringData:
  type: git
  url: https://github.com/YOUR_ORG/todo-app-deployment.git
  password: YOUR_GITHUB_TOKEN  # Personal access token
  username: not-used
```

Apply the secret:

```bash
kubectl apply -f argocd/github-secret.yaml
```

#### 8.2 Update ArgoCD Application Manifest

Edit `argocd/application.yaml`:

```yaml
source:
  repoURL: https://github.com/YOUR_ORG/todo-app-deployment.git
  targetRevision: main
  path: k8s
```

#### 8.3 Create ArgoCD Application

```bash
# Apply ArgoCD Application
kubectl apply -f argocd/application.yaml

# Verify application
kubectl get applications -n argocd

# Watch sync status
kubectl get application todo-app -n argocd -w
```

### Phase 9: Setup CircleCI

#### 9.1 Connect GitHub Repository to CircleCI

1. Go to https://circleci.com/
2. Sign in with GitHub
3. Click "Set Up Project"
4. Select your todo-app repository
5. Click "Set Up Project"

#### 9.2 Set Environment Variables

In CircleCI project settings, add:

```
AWS_ACCESS_KEY_ID         = your-access-key
AWS_SECRET_ACCESS_KEY     = your-secret-key
AWS_REGION                = us-east-1
AWS_ECR_REGISTRY          = YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
GITHUB_TOKEN              = your-github-token
GITHUB_USER               = your-github-username
```

#### 9.3 Configure GitHub Webhooks

CircleCI automatically configures webhooks when connecting a repository.

Verify in GitHub repository Settings > Webhooks:
- CircleCI webhook should be present
- Should fire on push events

### Phase 10: First Deployment

#### 10.1 Trigger CircleCI Pipeline

```bash
# Make a commit to main branch
git add .
git commit -m "Trigger initial deployment"
git push origin main
```

#### 10.2 Monitor Pipeline

- Go to CircleCI dashboard
- Watch the pipeline run through stages:
  1. Build & Test
  2. Push Image
  3. Update K8s Manifests
  4. Manual Approval
  5. ArgoCD Deployment

#### 10.3 Verify Deployment

```bash
# Check ArgoCD application sync status
kubectl get application todo-app -n argocd

# Verify pods are running
kubectl get pods -n todo-app

# Check application logs
kubectl logs -f deployment/todo-app-deployment -n todo-app
```

## Verification Checklist

- [ ] AWS credentials configured and verified
- [ ] S3 bucket and DynamoDB lock table created
- [ ] Terraform initialized and plan reviewed
- [ ] EKS cluster created and nodes ready
- [ ] kubectl configured and connected
- [ ] Docker image built and pushed to ECR
- [ ] Kubernetes manifests applied successfully
- [ ] Application pods running and healthy
- [ ] LoadBalancer service has external IP
- [ ] Application accessible via web browser
- [ ] ArgoCD installed and running
- [ ] GitHub credentials configured in ArgoCD
- [ ] ArgoCD Application created and synced
- [ ] CircleCI pipeline configured and running

## Next Steps

1. **Monitor Application**: Set up monitoring/alerting using CloudWatch or Prometheus
2. **Configure DNS**: Set up Route53 for domain name
3. **Setup SSL/TLS**: Configure certificate using ACM
4. **Backup Strategy**: Configure backup policies for DynamoDB and S3
5. **Cost Optimization**: Review AWS costs and optimize resource sizing
6. **Documentation**: Create runbooks for common operations

## Troubleshooting

### Terraform Init Fails
```bash
# Clear Terraform cache
rm -rf .terraform
rm -rf .terraform.lock.hcl

# Reinitialize
terraform init
```

### EKS Cluster Creation Timeout
- Check AWS service quotas
- Verify IAM permissions
- Check VPC/subnet configuration

### Pods Not Starting
```bash
# Check pod events
kubectl describe pod <pod-name> -n todo-app

# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check resource usage
kubectl top nodes
```

### ArgoCD Sync Fails
```bash
# Check repository connection
kubectl logs -n argocd deployment/argocd-repo-server

# Verify GitHub credentials
kubectl get secret github-credentials -n argocd -o yaml
```

For more troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
