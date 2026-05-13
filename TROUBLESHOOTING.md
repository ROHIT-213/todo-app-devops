# Troubleshooting Guide

## Common Issues and Solutions

### AWS Issues

#### Issue 1: AWS Authentication Failures

**Symptom**: `Unable to locate credentials` or `An error occurred (UnauthorizedOperation)`

**Solution**:
```bash
# Verify credentials are set
aws sts get-caller-identity

# If not set, configure AWS CLI
aws configure

# Verify IAM permissions
aws iam get-user

# Check credential expiration
aws sts get-caller-identity --query 'UserId'

# For temporary credentials (MFA)
aws sts get-session-token --duration-seconds 3600

# Set temporary credentials
export AWS_ACCESS_KEY_ID=<temp-key>
export AWS_SECRET_ACCESS_KEY=<temp-secret>
export AWS_SESSION_TOKEN=<token>
```

#### Issue 2: Insufficient IAM Permissions

**Symptom**: `User: arn:aws:iam::XXX:user/YYY is not authorized to perform: eks:CreateCluster`

**Solution**:
```bash
# Check attached policies
aws iam list-attached-user-policies --user-name <username>

# Add required policy
aws iam attach-user-policy \
  --user-name <username> \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# For restricted access, use specific policies:
# - AmazonEKSFullAccess
# - IAMFullAccess
# - AmazonVPCFullAccess
# - AmazonEC2FullAccess
# - AmazonS3FullAccess
# - DynamoDBFullAccess
```

#### Issue 3: S3 Bucket Name Already Exists

**Symptom**: `An error occurred (BucketAlreadyExists) when calling the CreateBucket operation`

**Solution**:
```bash
# S3 bucket names must be globally unique
# Use a different name with timestamp or account ID

export TIMESTAMP=$(date +%s)
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export NEW_BUCKET="todo-app-terraform-state-${ACCOUNT_ID}-${TIMESTAMP}"

# Update Terraform backend configuration
# Edit terraform/provider.tf with new bucket name
```

### Terraform Issues

#### Issue 1: Terraform State Corruption

**Symptom**: `Error: state push failed`

**Solution**:
```bash
# Backup current state
terraform state pull > terraform.tfstate.backup

# Show current state
terraform show

# Check for syntax errors
terraform validate

# Refresh state from AWS
terraform refresh

# If still failing, rebuild state
terraform state rm <resource>
terraform apply
```

#### Issue 2: Lock Timeout on Terraform State

**Symptom**: `Error acquiring the state lock: ConditionalCheckFailedException`

**Solution**:
```bash
# View lock information
terraform state list

# Force unlock (use with caution)
terraform force-unlock <LOCK-ID>

# Alternative: Delete lock from DynamoDB
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID":{"S":"path/to/terraform.tfstate"}}'

# Verify lock is removed
terraform plan
```

#### Issue 3: VPC/Subnet Configuration Error

**Symptom**: `Error creating EKS cluster: InvalidParameterException: Subnet IDs must have route tables`

**Solution**:
```bash
# Verify subnets exist
aws ec2 describe-subnets --region us-east-1

# Verify route tables
aws ec2 describe-route-tables --region us-east-1

# Check subnet associations
aws ec2 describe-subnets --subnet-ids <subnet-id> --region us-east-1

# Recreate if needed
terraform taint aws_subnet.private[0]
terraform apply
```

### EKS Issues

#### Issue 1: EKS Cluster Creation Timeout

**Symptom**: Terraform hangs on `aws_eks_cluster.main` creation

**Solution**:
```bash
# Check AWS CloudFormation events
aws cloudformation describe-stacks \
  --stack-name eksctl-todo-app-eks-cluster \
  --region us-east-1 \
  --query 'Stacks[0].StackEvents'

# Check EKS cluster logs
aws eks describe-cluster \
  --name todo-app-eks \
  --region us-east-1 \
  --query 'cluster.logging'

# Enable all cluster logs
aws logs describe-log-groups --query 'logGroups[?contains(logGroupName, `eks`)]'

# Check for quota issues
aws service-quotas list-service-quotas \
  --service-code ec2 \
  --query 'ServiceQuotas[?contains(QuotaName, `VPC`)]'

# Increase quota if needed
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-XXX \
  --desired-value 100
```

#### Issue 2: kubectl Cannot Connect to Cluster

**Symptom**: `The server has asked for the client to provide credentials`

**Solution**:
```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --region us-east-1 \
  --name todo-app-eks

# Verify kubeconfig
kubectl config view

# Check cluster endpoint
aws eks describe-cluster \
  --name todo-app-eks \
  --query 'cluster.endpoint'

# Test connection
kubectl cluster-info

# Check kubectl version compatibility
kubectl version --client
aws eks describe-cluster --name todo-app-eks --query 'cluster.version'
```

#### Issue 3: Node Group Not Ready

**Symptom**: Nodes stuck in `NotReady` state

**Solution**:
```bash
# Describe node group
aws eks describe-nodegroup \
  --cluster-name todo-app-eks \
  --nodegroup-name todo-app-node-group \
  --region us-east-1

# Check node status in kubectl
kubectl get nodes -o wide

# Describe node for details
kubectl describe node <node-name>

# Check node logs (requires SSM Session Manager)
aws ssm start-session --target <instance-id>

# View EC2 instance status
aws ec2 describe-instance-status \
  --instance-ids <instance-id> \
  --region us-east-1

# If failing, delete and recreate node group
aws eks delete-nodegroup \
  --cluster-name todo-app-eks \
  --nodegroup-name todo-app-node-group \
  --region us-east-1

# Recreate with Terraform
terraform taint aws_eks_node_group.main
terraform apply
```

### Docker Issues

#### Issue 1: Docker Image Build Fails

**Symptom**: `failed to build: docker build exited with error`

**Solution**:
```bash
# Build with verbose output
docker build --progress=plain -t todo-app:latest .

# Check Dockerfile for syntax errors
docker build --rm -t todo-app:test . 2>&1 | head -20

# Verify base image availability
docker pull node:18-alpine

# Check for missing files
ls -la src/
ls -la public/
ls -la Dockerfile

# Rebuild with no cache
docker build --no-cache -t todo-app:latest .
```

#### Issue 2: ECR Image Push Fails

**Symptom**: `denied: User is not authorized to perform: ecr:BatchCheckLayerAvailability`

**Solution**:
```bash
# Verify ECR repository exists
aws ecr describe-repositories --repository-names todo-app --region us-east-1

# Re-authenticate with ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Check Docker daemon is running
docker ps

# Verify image exists locally
docker images | grep todo-app

# Push with debug output
docker push <registry>/todo-app:latest -v

# If still failing, recreate repository
aws ecr delete-repository \
  --repository-name todo-app \
  --force \
  --region us-east-1

aws ecr create-repository \
  --repository-name todo-app \
  --region us-east-1
```

#### Issue 3: Image Pull Errors in Kubernetes

**Symptom**: `Failed to pull image "xxx": rpc error: code = Unknown desc = Error response from daemon`

**Solution**:
```bash
# Check image URI in deployment
kubectl get deployment todo-app-deployment -n todo-app -o yaml | grep image

# Verify image exists in ECR
aws ecr describe-images \
  --repository-name todo-app \
  --region us-east-1

# Check image tag
aws ecr list-images \
  --repository-name todo-app \
  --region us-east-1

# Verify image pull policy
# If using imagePullPolicy: Always, ensure image exists with correct tag

# Check for image pull secrets
kubectl get secrets -n todo-app

# Create image pull secret if needed
kubectl create secret docker-registry ecr-credentials \
  --docker-server=<account-id>.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  -n todo-app
```

### Kubernetes Issues

#### Issue 1: Pods Stuck in Pending

**Symptom**: Pods remain in `Pending` state

**Solution**:
```bash
# Check pod events
kubectl describe pod <pod-name> -n todo-app

# Check node capacity
kubectl describe nodes

# View node resource allocation
kubectl top nodes

# Check for node selector/affinity issues
kubectl get deployment todo-app-deployment -n todo-app -o yaml | grep -A 5 "affinity"

# Check storage availability
kubectl get pvc -n todo-app

# If no nodes available, scale cluster
aws eks update-nodegroup-config \
  --cluster-name todo-app-eks \
  --nodegroup-name todo-app-node-group \
  --scaling-config minSize=3,maxSize=10,desiredSize=5

# Reduce pod resource requests if necessary
kubectl set resources deployment todo-app-deployment \
  --requests=cpu=50m,memory=64Mi \
  -n todo-app
```

#### Issue 2: CrashLoopBackOff

**Symptom**: Pods restart continuously

**Solution**:
```bash
# Check container logs
kubectl logs <pod-name> -n todo-app

# View previous logs (before crash)
kubectl logs <pod-name> --previous -n todo-app

# Describe pod for exit code
kubectl describe pod <pod-name> -n todo-app

# Common exit codes:
# 0 = Normal exit
# 1 = General error
# 2 = Misuse of exit
# 125 = Docker daemon error
# 126 = Cannot invoke specified command
# 127 = File not found
# 128 + N = Fatal signal N

# Check liveness probe
kubectl get deployment todo-app-deployment -n todo-app -o yaml | grep -A 5 "livenessProbe"

# Increase liveness probe delay
kubectl patch deployment todo-app-deployment -n todo-app --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/initialDelaySeconds", "value":60}]'

# Check application health endpoint
kubectl port-forward <pod-name> 3000:3000 -n todo-app
curl http://localhost:3000/health
```

#### Issue 3: Insufficient Resources / OOM Kills

**Symptom**: `Killed` status or `Out of memory`

**Solution**:
```bash
# Check resource limits
kubectl get deployment todo-app-deployment -n todo-app -o yaml | grep -A 10 "resources:"

# Monitor current usage
kubectl top pods -n todo-app

# Increase memory limit
kubectl set resources deployment todo-app-deployment \
  --limits=memory=1Gi \
  -n todo-app

# View memory usage over time
kubectl top pods -n todo-app --containers

# Check for memory leaks in application
# Monitor with: kubectl top pods -n todo-app -w

# Scale to more pods if needed
kubectl scale deployment todo-app-deployment --replicas=5 -n todo-app
```

#### Issue 4: Service Not Getting External IP

**Symptom**: LoadBalancer service shows `<pending>` for EXTERNAL-IP

**Solution**:
```bash
# Check service status
kubectl describe service todo-app-service -n todo-app

# Check if AWS load balancer controller is installed
kubectl get deployment -n kube-system | grep aws-load-balancer-controller

# Install if missing
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system

# Check service annotations
kubectl get svc todo-app-service -n todo-app -o yaml | grep annotations

# Verify security group rules
aws ec2 describe-security-groups \
  --filter "Name=group-name,Values=todo-app-*" \
  --region us-east-1

# Wait a few more minutes (AWS typically takes 1-3 minutes)
kubectl get svc -n todo-app -w

# If still pending, check CloudFormation
aws cloudformation describe-stacks \
  --query 'Stacks[?contains(StackName, `k8s`)]'
```

### DynamoDB Issues

#### Issue 1: DynamoDB Throttling

**Symptom**: `ProvisionedThroughputExceededException`

**Solution**:
```bash
# Check current billing mode
aws dynamodb describe-table --table-name todo-app-items --query 'Table.BillingModeSummary'

# Already using PAY_PER_REQUEST (on-demand) - no throttling should occur

# If using provisioned mode, increase capacity:
aws dynamodb update-table \
  --table-name todo-app-items \
  --provisioned-throughput ReadCapacityUnits=100,WriteCapacityUnits=100

# Monitor metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=todo-app-items \
  --start-time 2024-05-01T00:00:00Z \
  --end-time 2024-05-08T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

#### Issue 2: DynamoDB Query/Scan Issues

**Symptom**: Slow queries or `ResourceNotFoundException`

**Solution**:
```bash
# Verify table exists
aws dynamodb describe-table --table-name todo-app-items

# Check table status
aws dynamodb describe-table --table-name todo-app-items --query 'Table.TableStatus'

# List table items
aws dynamodb scan --table-name todo-app-items --max-items 10

# Check indexes
aws dynamodb describe-table --table-name todo-app-items --query 'Table.GlobalSecondaryIndexes'

# Query with specific key
aws dynamodb query \
  --table-name todo-app-items \
  --key-condition-expression "user_id = :uid" \
  --expression-attribute-values '{":uid":{"S":"user123"}}'

# Scan for debugging
aws dynamodb scan \
  --table-name todo-app-items \
  --projection-expression "user_id, todo_id"
```

### S3 Issues

#### Issue 1: S3 Bucket Access Denied

**Symptom**: `Access Denied` when accessing S3 bucket

**Solution**:
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket todo-app-data

# Check public access block
aws s3api get-public-access-block --bucket todo-app-data

# Verify IAM user permissions
aws iam get-user-policy --user-name <username> --policy-name <policy>

# Add S3 permissions to IAM user
aws iam attach-user-policy \
  --user-name <username> \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# List objects in bucket
aws s3 ls s3://todo-app-data/
```

#### Issue 2: S3 Cross-Region Replication Issues

**Symptom**: Files not replicating to destination bucket

**Solution**:
```bash
# Check replication configuration
aws s3api get-bucket-replication --bucket todo-app-data

# Enable versioning on both buckets
aws s3api put-bucket-versioning \
  --bucket todo-app-data \
  --versioning-configuration Status=Enabled

# Check IAM role permissions
aws iam get-role-policy --role-name s3-replication --policy-name replication

# Check replication status
aws s3api get-bucket-replication --bucket todo-app-data --query 'ReplicationConfiguration.Role'
```

### ArgoCD Issues

#### Issue 1: ArgoCD Cannot Connect to Git Repository

**Symptom**: `Failed to authenticate GitHub repository`

**Solution**:
```bash
# Check repository credentials
kubectl get secret github-credentials -n argocd -o yaml

# Verify GitHub token is valid
# The token should have 'repo' scope permissions

# Check ArgoCD server logs
kubectl logs deployment/argocd-server -n argocd | grep -i "error"

# Check repo-server logs
kubectl logs deployment/argocd-repo-server -n argocd | grep -i "git"

# Test git clone manually
git clone https://github.com/YOUR_ORG/todo-app-deployment.git

# Update GitHub secret if token expired
kubectl delete secret github-credentials -n argocd
kubectl apply -f argocd/github-secret.yaml

# Retest connection in ArgoCD UI
```

#### Issue 2: ArgoCD Application Not Syncing

**Symptom**: Application status stuck in `OutOfSync`

**Solution**:
```bash
# Check application status
kubectl describe application todo-app -n argocd

# Check for manifest errors
kubectl get application todo-app -n argocd -o yaml

# View diff
argocd app diff todo-app

# Check repository status in ArgoCD
argocd repo list

# Manually sync application
argocd app sync todo-app --grpc-web

# Check repo-server logs
kubectl logs deployment/argocd-repo-server -n argocd -f

# If still failing, recreate application
kubectl delete application todo-app -n argocd
kubectl apply -f argocd/application.yaml
```

#### Issue 3: ArgoCD Server Unreachable

**Symptom**: `Connection refused` when accessing ArgoCD UI

**Solution**:
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check service
kubectl get svc -n argocd

# Port forward if LoadBalancer not working
kubectl port-forward svc/argocd-server -n argocd 8443:443

# Check server logs
kubectl logs deployment/argocd-server -n argocd

# Describe service
kubectl describe svc argocd-server -n argocd

# Check for image pull errors
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server
```

### CircleCI Issues

#### Issue 1: CircleCI Pipeline Fails to Build

**Symptom**: Build job fails in CircleCI dashboard

**Solution**:
```bash
# Check CircleCI config syntax
circleci config validate .circleci/config.yml

# View build logs in CircleCI dashboard

# Common issues:
# - Missing environment variables: Check project settings
# - Docker build fails: Check Dockerfile syntax
# - npm install fails: Check package.json

# Retry failed job in CircleCI UI
# Or push a new commit to retry
git commit --allow-empty -m "Retry build"
git push origin main
```

#### Issue 2: Image Push Fails in CircleCI

**Symptom**: `denied: User is not authorized`

**Solution**:
```bash
# Verify AWS credentials in CircleCI
# Go to: Project Settings > Environment Variables

# Check variables:
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# AWS_REGION
# AWS_ECR_REGISTRY

# Test locally
export AWS_ACCESS_KEY_ID=<key>
export AWS_SECRET_ACCESS_KEY=<secret>
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <registry>

# View CircleCI logs for detailed error
```

#### Issue 3: Manual Approval Never Appears

**Symptom**: CircleCI pipeline stuck or missing approval step

**Solution**:
```bash
# Check .circleci/config.yml for hold job configuration

# Verify hold job exists
grep -n "hold_deploy:" .circleci/config.yml

# Verify it's in workflow
grep -n "workflows:" .circleci/config.yml

# Commit fix
git add .circleci/config.yml
git commit -m "Fix: Add missing approval step"
git push origin main

# Check CircleCI dashboard for updated workflow
```

## Debugging Commands Reference

```bash
# Kubernetes debugging
kubectl describe pod <pod-name> -n todo-app          # Pod details
kubectl logs <pod-name> -n todo-app                  # Container logs
kubectl get events -n todo-app                        # Cluster events
kubectl top nodes                                     # Node metrics
kubectl top pods -n todo-app                          # Pod metrics
kubectl get all -n todo-app                           # All resources
kubectl exec <pod> -it -- bash -n todo-app           # Access container

# AWS debugging
aws ec2 describe-instances --region us-east-1        # EC2 instances
aws logs tail /aws/eks/todo-app-eks/cluster           # EKS logs
aws cloudformation describe-stacks --query 'Stacks'  # CloudFormation

# ArgoCD debugging
argocd app list                                       # All applications
argocd app get todo-app                              # App details
argocd app diff todo-app                             # Sync diff
argocd repo list                                      # Repository status

# Docker debugging
docker ps                                             # Running containers
docker logs <container>                              # Container logs
docker inspect <image>                               # Image details
docker system df                                      # Disk usage
```

## Getting Help

If you encounter an issue not covered in this guide:

1. Check AWS CloudWatch logs
2. Check Kubernetes events and pod logs
3. Check ArgoCD application status and logs
4. Check CircleCI build logs
5. Review application logs in the pod
6. Check GitHub issues in relevant projects
7. Post on Stack Overflow with relevant tags

## Support Resources

- [AWS EKS Troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [ArgoCD Troubleshooting](https://argo-cd.readthedocs.io/en/stable/operator-manual/troubleshooting/)
- [CircleCI Support](https://support.circleci.com/)
