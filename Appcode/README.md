# Automating Deployment of a Dockerized ToDo App on AWS EKS Using GitOps and ArgoCD

## 📋 Project Overview

This project demonstrates a complete end-to-end solution for deploying a React-based ToDo application on AWS EKS (Elastic Kubernetes Service) using GitOps principles and ArgoCD. The architecture leverages modern DevOps practices with CI/CD automation through CircleCI.

### 🏗️ Architecture Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
│              (Source Code + Kubernetes Manifests)                │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │  CircleCI    │
                    │   Pipeline   │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    ┌───▼───┐       ┌──────▼────┐    ┌────────▼──┐
    │ Build │       │Push to ECR│    │ Update K8s│
    │&Test  │       │ Registry  │    │ Manifests │
    └───────┘       └───────────┘    └────┬──────┘
                                           │
                                    ┌──────▼──────┐
                                    │   GitHub    │
                                    │  (Manifest) │
                                    └──────┬──────┘
                                           │
                                    ┌──────▼──────┐
                                    │   ArgoCD    │
                                    │ (GitOps)    │
                                    └──────┬──────┘
                                           │
                ┌──────────────────────────┼──────────────────────┐
                │                          │                      │
        ┌───────▼────────┐        ┌────────▼────────┐    ┌───────▼───────┐
        │  AWS EKS       │        │    DynamoDB     │    │   S3 Bucket   │
        │  Kubernetes    │        │   (Data Store)  │    │   (Backups)   │
        │  Cluster       │        └─────────────────┘    └───────────────┘
        └────────────────┘
```

### 🎯 Key Features

- **Containerized Application**: React ToDo app with multi-stage Docker builds
- **Infrastructure as Code (IaC)**: Complete AWS infrastructure provisioned with Terraform
- **CI/CD Pipeline**: Automated testing, building, and deployment with CircleCI
- **GitOps Workflow**: Declarative deployments synchronized with git repository via ArgoCD
- **High Availability**: Multi-node EKS cluster with auto-scaling and load balancing
- **Data Persistence**: DynamoDB for application data and S3 for backups
- **Security**: IAM roles, service accounts, pod security policies, and encrypted secrets
- **Monitoring**: CloudWatch logs and optional Prometheus/Grafana stack

## 📁 Project Structure

```
├── Dockerfile                      # Multi-stage Docker build configuration
├── package.json                    # Node.js dependencies
├── src/                            # React application source code
├── public/                         # Static assets
├── k8s/                           # Kubernetes manifests
│   ├── namespace.yaml             # Namespace for todo-app
│   ├── deployment.yaml            # Deployment configuration
│   ├── service.yaml               # Service (LoadBalancer)
│   ├── configmap.yaml             # Application configuration
│   ├── serviceaccount.yaml        # Service account
│   ├── hpa.yaml                   # Horizontal Pod Autoscaler
│   └── ingress.yaml               # Ingress configuration
├── terraform/                     # Infrastructure as Code
│   ├── provider.tf                # AWS provider & backend config
│   ├── variables.tf               # Variable definitions
│   ├── vpc.tf                     # VPC and networking
│   ├── eks.tf                     # EKS cluster and node groups
│   ├── iam.tf                     # IAM roles and policies
│   ├── dynamodb.tf                # DynamoDB tables
│   ├── s3.tf                      # S3 buckets
│   ├── outputs.tf                 # Output values
│   └── terraform.tfvars.example   # Example variables
├── .circleci/                     # CircleCI configuration
│   └── config.yml                 # CI/CD pipeline definition
├── argocd/                        # ArgoCD configuration
│   ├── application.yaml           # ArgoCD Application manifest
│   ├── namespace.yaml             # ArgoCD namespace
│   ├── configmap.yaml             # ArgoCD config
│   ├── github-secret.yaml         # GitHub credentials
│   ├── ecr-secret.yaml            # ECR credentials
│   └── install-argocd.sh          # ArgoCD installation script
└── docs/                          # Documentation
    ├── SETUP.md                   # Setup instructions
    ├── DEPLOYMENT.md              # Deployment guide
    └── TROUBLESHOOTING.md         # Troubleshooting guide
```

## 🚀 Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- Docker installed and running
- kubectl CLI installed (v1.20+)
- Terraform installed (v1.0+)
- CircleCI account connected to GitHub
- Git repository set up

### Step 1: Prepare AWS Environment

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_REGION=us-east-1
```

### Step 2: Create Terraform State Backend

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket todo-app-terraform-state-$(aws sts get-caller-identity --query Account --output text) \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket todo-app-terraform-state-$(aws sts get-caller-identity --query Account --output text) \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 3: Configure Terraform

```bash
cd terraform

# Copy example variables to actual file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your desired configuration
vim terraform.tfvars
```

### Step 4: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Save outputs (needed for kubectl configuration)
terraform output -json > ../terraform_outputs.json
```

### Step 5: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --region us-east-1 \
  --name todo-app-eks

# Verify connection
kubectl get nodes
```

### Step 6: Setup Docker Registry (ECR)

```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name todo-app \
  --region us-east-1

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com

# Build and push image
docker build -t todo-app:latest .
docker tag todo-app:latest $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com/todo-app:latest
docker push $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com/todo-app:latest
```

### Step 7: Install ArgoCD

```bash
cd argocd

# Make installation script executable
chmod +x install-argocd.sh

# Run installation script
./install-argocd.sh

# Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 8: Create ArgoCD Application

```bash
# Create GitHub credentials secret
kubectl apply -f github-secret.yaml

# Create ArgoCD Application
kubectl apply -f application.yaml

# Check application status
kubectl get applications -n argocd
```

## 🔄 CI/CD Pipeline Flow

### Pipeline Stages

1. **Build & Test**
   - Pull dependencies with `npm install`
   - Run unit tests with code coverage
   - Build React application

2. **Docker Image Build & Push**
   - Create multi-stage Docker image
   - Login to AWS ECR
   - Push image with commit SHA and latest tags

3. **Update Kubernetes Manifests**
   - Update deployment image tag in k8s/deployment.yaml
   - Commit changes to git repository
   - Push to trigger ArgoCD sync

4. **Manual Approval** (hold_deploy)
   - Require manual approval before production deployment

5. **ArgoCD Deployment**
   - Create/update ArgoCD Application
   - Sync application (pull from git → deploy to cluster)
   - Monitor rollout status

### CircleCI Configuration

The pipeline is configured in `.circleci/config.yml` with the following workflows:

**build_and_push workflow** (triggered on main branch):
- Builds application
- Pushes Docker image
- Updates Kubernetes manifests
- Requires manual approval
- Deploys via ArgoCD

**infrastructure workflow** (triggered on infrastructure branch):
- Plans Terraform changes
- Requires manual approval
- Applies infrastructure changes

### Environment Variables

Set these in CircleCI project settings:

```
AWS_ACCESS_KEY_ID          # AWS access key
AWS_SECRET_ACCESS_KEY      # AWS secret key
AWS_REGION                 # AWS region (e.g., us-east-1)
AWS_ECR_REGISTRY           # ECR registry URL
GITHUB_TOKEN               # GitHub personal access token
GITHUB_USER                # GitHub username
```

## 📊 Kubernetes Deployment Details

### Deployment Configuration

**Replicas**: 3 (high availability)
**Strategy**: RollingUpdate with maxSurge: 1, maxUnavailable: 1

### Resource Requests & Limits

```yaml
Resources:
  Requests:
    Memory: 128Mi
    CPU: 100m
  Limits:
    Memory: 512Mi
    CPU: 500m
```

### Health Checks

- **Liveness Probe**: HTTP GET / every 10s (30s initial delay)
- **Readiness Probe**: HTTP GET / every 5s (10s initial delay)

### Horizontal Pod Autoscaling (HPA)

- **Min Replicas**: 3
- **Max Replicas**: 10
- **Metrics**:
  - CPU Utilization: 70%
  - Memory Utilization: 80%

### Service Type

- **Type**: LoadBalancer (AWS Network Load Balancer)
- **Port**: 80 → 3000
- **Session Affinity**: ClientIP (3600s timeout)

## 🔐 Security Features

### IAM Security

- **Principle of Least Privilege**: Roles have minimal required permissions
- **OIDC Integration**: Service Account to IAM role mapping (IRSA)
- **Encryption**: State file encrypted at rest

### Pod Security

- **Non-root User**: Containers run as user 1000
- **Read-only Filesystem**: Application runs with read-only root FS
- **Security Context**: Capabilities dropped, privilege escalation disabled

### Network Security

- **Security Groups**: Separate groups for master and nodes
- **VPC Isolation**: Multi-AZ private subnets for nodes
- **NAT Gateway**: Outbound internet through NAT

### Data Security

- **Encryption at Rest**: S3 bucket and DynamoDB encrypted
- **Versioning**: S3 and Terraform state versioning enabled
- **Access Control**: S3 block public access policies

## 📈 Monitoring & Logging

### CloudWatch Logs

- **EKS Cluster Logs**: Enabled for api, audit, authenticator, controllerManager, scheduler
- **Log Retention**: 7 days (configurable)

### Application Metrics

- **Prometheus Scraping**: Annotations enabled in deployment
- **Metrics Port**: 3000

### Optional Monitoring Stack

Install Prometheus and Grafana for advanced monitoring:

```bash
# Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# Install Grafana
helm install grafana prometheus-community/grafana \
  --namespace monitoring
```

## 📦 Data Storage

### DynamoDB

**Primary Table**: `todo-app-items`
- Hash Key: `user_id`
- Range Key: `todo_id`
- GSI: created_at_index for time-based queries
- TTL: Automatic expiration via `expiration_time` attribute

**Sessions Table**: `todo-app-items-sessions`
- Hash Key: `session_id`
- TTL: Automatic expiration

**Features**:
- Point-in-time recovery enabled
- Stream specification (NEW_AND_OLD_IMAGES)
- Pay-per-request billing

### S3 Buckets

**App Data Bucket**: `todo-app-data-{account-id}`
- Versioning enabled
- Server-side encryption (AES256)
- Lifecycle policy: Archive to Glacier after 30 days, delete after 90 days
- Public access blocked

**Terraform State Bucket**: `todo-app-terraform-state-{account-id}`
- Versioning enabled
- Encryption enabled
- Public access blocked
- Used for Terraform state management

## 🔧 Troubleshooting

### Common Issues

#### 1. EKS Cluster Creation Fails

**Problem**: VPC or IAM permissions issue

**Solution**:
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify IAM permissions
aws iam get-user

# Review Terraform logs
terraform show
```

#### 2. Docker Image Push Fails

**Problem**: ECR authentication or repository not found

**Solution**:
```bash
# Re-authenticate with ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Verify repository exists
aws ecr describe-repositories --region us-east-1
```

#### 3. Pod Fails to Start

**Problem**: Image pull error or insufficient resources

**Solution**:
```bash
# Check pod status
kubectl describe pod <pod-name> -n todo-app

# View pod logs
kubectl logs <pod-name> -n todo-app

# Check node resources
kubectl top nodes
kubectl top pods -n todo-app
```

#### 4. ArgoCD Application Not Syncing

**Problem**: Git repository credentials or manifest issues

**Solution**:
```bash
# Check application status
kubectl describe application todo-app -n argocd

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Verify git repository access
kubectl get secret github-credentials -n argocd -o yaml
```

## 🧹 Cleanup

### Remove All Resources

```bash
# Delete ArgoCD Application
kubectl delete application todo-app -n argocd

# Destroy Kubernetes resources
kubectl delete namespace todo-app

# Destroy AWS infrastructure
cd terraform
terraform destroy

# Manually delete S3 bucket (contains state)
aws s3api delete-object --bucket todo-app-terraform-state-$(aws sts get-caller-identity --query Account --output text) --key "eks/terraform.tfstate"
aws s3api delete-bucket --bucket todo-app-terraform-state-$(aws sts get-caller-identity --query Account --output text)

# Delete ECR repository
aws ecr delete-repository \
  --repository-name todo-app \
  --region us-east-1 \
  --force
```

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [CircleCI Documentation](https://circleci.com/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Submit a pull request
4. Pipeline will automatically build and test

## 📝 License

This project is provided as-is for educational and demonstration purposes.

## 📧 Support

For issues, questions, or suggestions, please open an issue in the GitHub repository.

---

**Last Updated**: May 2024
**Project Version**: 1.0.0
