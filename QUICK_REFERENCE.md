# Quick Reference Guide

## Command Reference

### Deployment

```bash
# Full automated deployment
./deploy.sh

# Manual Terraform deployment
cd terraform
terraform init
terraform plan
terraform apply

# Manual Kubernetes deployment
kubectl apply -f k8s/

# Manual ArgoCD deployment
kubectl apply -f argocd/application.yaml

# Cleanup all resources
./cleanup.sh
```

### kubectl Common Commands

```bash
# Cluster information
kubectl cluster-info                              # Get cluster details
kubectl get nodes                                 # List nodes
kubectl top nodes                                 # Node resource usage
kubectl describe node <node-name>                 # Node details

# Namespaces
kubectl create namespace <name>                   # Create namespace
kubectl get namespaces                            # List namespaces
kubectl delete namespace <name>                   # Delete namespace

# Deployments
kubectl get deployments -n todo-app              # List deployments
kubectl describe deployment <name> -n todo-app   # Deployment details
kubectl set image deployment/<name> \
  container=image:tag -n todo-app               # Update image
kubectl scale deployment/<name> \
  --replicas=5 -n todo-app                      # Scale replicas
kubectl rollout status deployment/<name> -n todo-app      # Rollout status
kubectl rollout undo deployment/<name> -n todo-app        # Rollback

# Pods
kubectl get pods -n todo-app                     # List pods
kubectl get pods -n todo-app -w                  # Watch pods
kubectl describe pod <pod-name> -n todo-app      # Pod details
kubectl logs <pod-name> -n todo-app              # Container logs
kubectl logs <pod-name> --previous -n todo-app   # Previous logs (crash)
kubectl logs -f deployment/<name> -n todo-app    # Stream logs
kubectl exec -it <pod-name> -n todo-app -- bash # Shell access
kubectl port-forward <pod-name> 8080:3000 -n todo-app    # Port forward

# Services
kubectl get services -n todo-app                 # List services
kubectl describe service <name> -n todo-app      # Service details
kubectl port-forward service/<name> 8080:80 \
  -n todo-app                                   # Forward service

# ConfigMaps & Secrets
kubectl get configmaps -n todo-app               # List configmaps
kubectl get configmap <name> -n todo-app -o yaml # View configmap
kubectl set env deployment/<name> \
  --from=configmap=<cm> -n todo-app             # Use configmap
kubectl get secrets -n argocd                    # List secrets
kubectl get secret <name> -n argocd -o yaml      # View secret

# RBAC
kubectl get rbac                                 # List RBAC resources
kubectl create serviceaccount <name> -n <ns>     # Create service account
kubectl get serviceaccounts -n todo-app          # List service accounts

# Events & Monitoring
kubectl get events -n todo-app                   # Cluster events
kubectl describe events -n todo-app              # Event details
kubectl top pods -n todo-app                     # Pod metrics
kubectl describe pod <pod-name> -n todo-app      # Includes events

# Debugging
kubectl debug pod/<pod-name> -it -n todo-app    # Debug pod
kubectl get pod -o yaml -n todo-app              # Export pod YAML
kubectl diff -f <file>                           # Show diff before apply
```

### AWS CLI Commands

```bash
# Authentication
aws sts get-caller-identity                      # Verify credentials
aws configure                                    # Configure AWS CLI

# EKS
aws eks describe-cluster --name todo-app-eks     # Cluster details
aws eks update-kubeconfig --name todo-app-eks    # Update kubeconfig
aws eks list-nodegroups --cluster-name todo-app-eks   # List node groups
aws eks describe-nodegroup \
  --cluster-name todo-app-eks \
  --nodegroup-name todo-app-node-group         # Node group details

# EC2
aws ec2 describe-instances --region us-east-1    # List instances
aws ec2 describe-instance-status                 # Instance status
aws ec2 describe-security-groups                 # List security groups

# ECR
aws ecr describe-repositories                    # List repositories
aws ecr list-images --repository-name todo-app   # List images
aws ecr describe-images --repository-name todo-app  # Image details
aws ecr get-login-password | docker login \
  --username AWS --password-stdin <registry>    # Login to ECR

# DynamoDB
aws dynamodb list-tables                         # List tables
aws dynamodb describe-table --table-name <name>  # Table details
aws dynamodb scan --table-name <name>            # Scan table
aws dynamodb query --table-name <name> \
  --key-condition-expression "pk = :pk" \
  --expression-attribute-values '{":pk":{"S":"value"}}' # Query table

# S3
aws s3 ls                                        # List buckets
aws s3 ls s3://bucket-name/                      # List bucket objects
aws s3api list-object-versions --bucket bucket-name # List versions
aws s3 cp file s3://bucket-name/                 # Upload file
aws s3 sync local-dir s3://bucket-name/          # Sync directory

# CloudWatch Logs
aws logs describe-log-groups                     # List log groups
aws logs tail /aws/eks/todo-app-eks/cluster      # Stream logs
aws logs describe-log-streams \
  --log-group-name /aws/eks/todo-app-eks/cluster # List streams

# Terraform
aws s3 ls s3://todo-app-terraform-state-*       # View state bucket
aws dynamodb scan --table-name terraform-locks   # View lock table
```

### Git Commands

```bash
# Repository
git clone <repo-url>                             # Clone repository
git status                                        # Check status
git log --oneline                                # View history

# Branching
git branch                                       # List branches
git checkout -b feature-name                     # Create branch
git push origin feature-name                     # Push branch
git pull origin main                             # Pull updates

# Commits
git add .                                         # Stage changes
git commit -m "message"                          # Create commit
git push origin branch-name                      # Push commits
git pull                                         # Fetch and merge

# Tags
git tag -a v1.0.0 -m "Release 1.0.0"            # Create tag
git push origin v1.0.0                           # Push tag
git tag -l                                       # List tags
```

### Docker Commands

```bash
# Images
docker images                                    # List images
docker build -t name:tag .                       # Build image
docker tag source:tag dest:tag                   # Tag image
docker pull image:tag                            # Pull image
docker push image:tag                            # Push image
docker rmi image:tag                             # Remove image

# Containers
docker ps                                        # List running containers
docker ps -a                                     # All containers
docker run -d -p 8080:80 image:tag               # Run container
docker logs container-name                       # View logs
docker exec -it container-name bash              # Shell access
docker stop container-name                       # Stop container
docker rm container-name                         # Remove container

# Build
docker build --no-cache -t image:tag .           # Build without cache
docker build -f Dockerfile.prod -t image:tag .   # Alternate Dockerfile
```

### Terraform Commands

```bash
# Initialization
terraform init                                   # Initialize terraform
terraform init -upgrade                          # Upgrade providers

# Planning
terraform plan                                   # Show what will change
terraform plan -out=tfplan                       # Save plan
terraform show tfplan                            # View saved plan

# Applying
terraform apply                                  # Apply changes
terraform apply tfplan                           # Apply saved plan
terraform apply -auto-approve                    # Skip approval

# Querying
terraform state list                             # List resources
terraform state show <resource>                  # Show resource details
terraform output                                 # Show outputs
terraform show                                   # Show all state

# Cleanup
terraform destroy                                # Destroy resources
terraform destroy -auto-approve                  # Skip approval
terraform state rm <resource>                    # Remove from state
terraform taint <resource>                       # Mark for recreation
```

### ArgoCD Commands

```bash
# Application
argocd app list                                  # List applications
argocd app get todo-app                          # Get app details
argocd app history todo-app                      # View sync history
argocd app resources todo-app                    # View resources
argocd app diff todo-app                         # Show diff

# Sync
argocd app sync todo-app                         # Sync application
argocd app sync todo-app --grpc-web              # Sync (via web)
argocd app wait todo-app                         # Wait for sync

# Management
argocd app create <name> --repo <url>           # Create app
argocd app delete <name>                         # Delete app
argocd app set <name> --path <path>              # Set path

# Status
argocd app logs todo-app                         # View logs
argocd app info todo-app                         # App info
argocd repo list                                 # List repos
```

### CircleCI Commands

```bash
# Validate configuration
circleci config validate .circleci/config.yml    # Validate config
circleci config pack .circleci > config.yml      # Pack config

# Local testing (requires CircleCI CLI)
circleci build                                   # Run pipeline locally
```

## Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Kubernetes
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kn='kubectl config set-context --current --namespace'

# Terraform
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfs='terraform state'

# AWS
alias awsl='aws sts get-caller-identity'
alias awse='aws eks'

# Docker
alias d='docker'
alias di='docker images'
alias dps='docker ps'
alias dl='docker logs'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gpl='git pull'
alias gl='git log'
```

## Port Forwarding

```bash
# Application
kubectl port-forward svc/todo-app-service -n todo-app 8080:80
# Access: http://localhost:8080

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8443:443
# Access: https://localhost:8443

# Specific pod
kubectl port-forward pod/todo-app-abc123 -n todo-app 3000:3000
# Access: http://localhost:3000
```

## Environment Variables

```bash
# AWS
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret

# Kubernetes
export KUBECONFIG=~/.kube/config

# Application
export TODO_APP_ENV=production
export TODO_APP_LOG_LEVEL=info

# CircleCI
export CIRCLECI_TOKEN=your-token

# GitHub
export GITHUB_TOKEN=your-token
```

## File Locations

```
Repository Root/
├── README.md                    # Project overview
├── SETUP.md                     # Setup guide
├── DEPLOYMENT.md                # Deployment guide
├── TROUBLESHOOTING.md           # Troubleshooting guide
├── ARCHITECTURE.md              # Architecture documentation
├── Dockerfile                   # Container definition
├── package.json                 # Dependencies
├── deploy.sh                    # Deployment script
├── cleanup.sh                   # Cleanup script
│
├── src/                         # Application source
├── public/                      # Static assets
├── k8s/                         # Kubernetes manifests
├── terraform/                   # Infrastructure code
├── .circleci/                   # CI/CD pipeline
└── argocd/                      # GitOps configuration
```

## Monitoring Commands

```bash
# Real-time monitoring
watch kubectl top nodes
watch kubectl get pods -n todo-app
watch kubectl get application -n argocd

# Logs
kubectl logs -f deployment/todo-app-deployment -n todo-app
kubectl logs -f deployment/argocd-server -n argocd

# Events
kubectl get events -n todo-app --sort-by='.lastTimestamp'

# Resource usage
kubectl describe nodes
kubectl describe pod <pod-name> -n todo-app
```

## Useful Scripts

```bash
# Get LoadBalancer URL
kubectl get svc todo-app-service -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Stream logs from all pods
kubectl logs -f deployment/todo-app-deployment -n todo-app

# Watch pod creation
kubectl get pods -n todo-app -w

# Restart deployment
kubectl rollout restart deployment/todo-app-deployment -n todo-app

# Check cluster events
kubectl get events -n todo-app --sort-by='.metadata.creationTimestamp'
```

## Key Files to Know

- **Kubernetes Deployment**: `k8s/deployment.yaml`
- **Terraform Main**: `terraform/eks.tf`
- **CircleCI Config**: `.circleci/config.yml`
- **ArgoCD App**: `argocd/application.yaml`
- **Docker Build**: `Dockerfile`
- **Dependencies**: `package.json`

## Common Troubleshooting Shortcuts

```bash
# Pod won't start
kubectl describe pod <pod-name> -n todo-app
kubectl logs <pod-name> -n todo-app --previous

# Check cluster health
kubectl get nodes
kubectl get componentstatuses

# Check resource availability
kubectl describe nodes
kubectl top nodes

# Check service routing
kubectl get svc
kubectl describe svc todo-app-service -n todo-app
kubectl get endpoints -n todo-app
```

---

For detailed guides, see:
- [README.md](README.md) - Project overview
- [SETUP.md](SETUP.md) - Detailed setup
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment strategies
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem solving
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design
