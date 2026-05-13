# Deployment Guide

## Overview

This document provides detailed guidance on deploying and managing the ToDo application in production.

## Deployment Models

### Model 1: Manual Deployment (Development/Testing)

```bash
# 1. Build Docker image locally
docker build -t todo-app:v1.0.0 .

# 2. Tag for registry
docker tag todo-app:v1.0.0 your-registry/todo-app:v1.0.0

# 3. Push to registry
docker push your-registry/todo-app:v1.0.0

# 4. Update Kubernetes manifests
sed -i 's|image: .*|image: your-registry/todo-app:v1.0.0|' k8s/deployment.yaml

# 5. Apply to cluster
kubectl apply -f k8s/

# 6. Monitor rollout
kubectl rollout status deployment/todo-app-deployment -n todo-app
```

### Model 2: CI/CD Pipeline Deployment (Recommended)

```bash
# 1. Push code to main branch
git add .
git commit -m "Feature: Add new functionality"
git push origin main

# 2. CircleCI pipeline automatically:
#    - Builds and tests code
#    - Builds Docker image
#    - Pushes to ECR
#    - Updates Kubernetes manifests
#    - Requests manual approval
#    - Syncs with ArgoCD

# 3. Monitor pipeline in CircleCI dashboard
# 4. Approve deployment when ready
# 5. Application automatically deployed by ArgoCD
```

### Model 3: GitOps Deployment (Full Automation)

```bash
# 1. Update Kubernetes manifests in git
vim k8s/deployment.yaml

# 2. Commit changes
git add k8s/
git commit -m "Update deployment configuration"
git push origin main

# 3. ArgoCD automatically:
#    - Detects git changes
#    - Compares with cluster state
#    - Applies changes to cluster
#    - Updates application status

# 4. Verify deployment
kubectl get applications -n argocd
argocd app get todo-app
```

## Deployment Strategies

### Rolling Update (Default)

Configuration in `k8s/deployment.yaml`:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1           # 1 extra pod during update
    maxUnavailable: 1     # 1 pod can be down during update
```

**Process**:
1. Create 1 new pod with new version
2. Wait for readiness probe to pass
3. Terminate 1 old pod
4. Repeat until all pods updated

**Benefits**:
- Zero downtime
- Quick rollback if needed

**Example**:
```bash
# Trigger update
kubectl set image deployment/todo-app-deployment \
  todo-app=your-registry/todo-app:v2.0 \
  -n todo-app

# Monitor update
kubectl rollout status deployment/todo-app-deployment -n todo-app

# Rollback if needed
kubectl rollout undo deployment/todo-app-deployment -n todo-app
```

### Blue-Green Deployment

**Setup**:
```bash
# Create separate deployments
kubectl apply -f k8s/deployment-blue.yaml   # Current version
kubectl apply -f k8s/deployment-green.yaml  # New version

# Service points to blue
kubectl apply -f k8s/service-blue.yaml

# When green is tested, switch service to green
kubectl patch service todo-app-service -n todo-app \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Keep blue running for instant rollback
```

**Benefits**:
- Instant rollback
- Full environment testing
- Zero downtime

### Canary Deployment

**Setup**:
```bash
# 1. Deploy canary version (5% of traffic)
kubectl apply -f k8s/deployment-canary.yaml

# 2. Update service with weighted routing
apiVersion: v1
kind: Service
metadata:
  name: todo-app-service
spec:
  selector:
    app: todo-app
  ports:
  - port: 80
    targetPort: 3000
  
  # Weighted routing via ingress
  
# 3. Monitor canary metrics
kubectl logs -f deployment/todo-app-canary -n todo-app

# 4. Gradually increase traffic
# Repeat at 10%, 25%, 50%, 100%

# 5. Remove canary when stable
kubectl delete deployment todo-app-canary -n todo-app
```

## Production Deployment Checklist

### Pre-Deployment
- [ ] Code reviewed and approved
- [ ] All tests passing
- [ ] Image scanned for vulnerabilities
- [ ] Configuration updated for environment
- [ ] Backup of current database taken
- [ ] Rollback plan documented
- [ ] Communication sent to team
- [ ] Monitoring alerts configured

### Deployment
- [ ] Execute deployment command
- [ ] Monitor initial pod creation
- [ ] Verify health checks passing
- [ ] Monitor CPU/memory usage
- [ ] Verify application functionality
- [ ] Check logs for errors
- [ ] Monitor metrics/dashboards

### Post-Deployment
- [ ] Verify all pods in running state
- [ ] Smoke tests passed
- [ ] User acceptance testing completed
- [ ] Performance baseline met
- [ ] Alerts not firing
- [ ] Documentation updated
- [ ] Deployment logged

## Monitoring Deployments

### Kubernetes Level Monitoring

```bash
# Watch pod status
kubectl get pods -n todo-app -w

# View deployment status
kubectl describe deployment todo-app-deployment -n todo-app

# Check rollout history
kubectl rollout history deployment/todo-app-deployment -n todo-app

# View revision details
kubectl rollout history deployment/todo-app-deployment -n todo-app --revision=2

# Get pod metrics
kubectl top pods -n todo-app
kubectl top nodes
```

### Application Level Monitoring

```bash
# Stream logs from all pods
kubectl logs -f deployment/todo-app-deployment -n todo-app

# View logs from specific pod
kubectl logs <pod-name> -n todo-app

# View logs from specific container
kubectl logs <pod-name> -c todo-app -n todo-app

# View previous pod logs (if crash)
kubectl logs <pod-name> --previous -n todo-app

# Stream logs with timestamps
kubectl logs -f deployment/todo-app-deployment -n todo-app --timestamps=true

# Get logs with grep filter
kubectl logs deployment/todo-app-deployment -n todo-app | grep ERROR
```

### ArgoCD Monitoring

```bash
# Check application status
kubectl get applications -n argocd

# Get detailed application info
kubectl describe application todo-app -n argocd

# Watch sync status
watch kubectl get application todo-app -n argocd -o wide

# Get application sync history
argocd app history todo-app

# Check diff before sync
argocd app diff todo-app

# Get resource status
argocd app resources todo-app
```

## Scaling Deployments

### Manual Scaling

```bash
# Scale to specific number of replicas
kubectl scale deployment todo-app-deployment -n todo-app --replicas=5

# View updated replicas
kubectl get deployment -n todo-app
```

### Horizontal Pod Autoscaler (HPA)

```bash
# View HPA status
kubectl get hpa -n todo-app

# Describe HPA
kubectl describe hpa todo-app-hpa -n todo-app

# Watch HPA scaling decisions
kubectl get hpa -n todo-app -w

# Check HPA metrics
kubectl get hpa todo-app-hpa -n todo-app --show-metrics
```

**HPA Configuration** (from `k8s/hpa.yaml`):
- Min Replicas: 3
- Max Replicas: 10
- CPU Target: 70%
- Memory Target: 80%

### Cluster Scaling

```bash
# View node group
aws eks describe-nodegroup \
  --cluster-name todo-app-eks \
  --nodegroup-name todo-app-node-group \
  --region us-east-1

# Update node group size
aws eks update-nodegroup-config \
  --cluster-name todo-app-eks \
  --nodegroup-name todo-app-node-group \
  --scaling-config minSize=3,maxSize=10,desiredSize=5 \
  --region us-east-1
```

## Rollback Procedures

### Application Rollback

```bash
# View rollout history
kubectl rollout history deployment/todo-app-deployment -n todo-app

# Rollback to previous version
kubectl rollout undo deployment/todo-app-deployment -n todo-app

# Rollback to specific revision
kubectl rollout undo deployment/todo-app-deployment -n todo-app --to-revision=2

# Verify rollback
kubectl rollout status deployment/todo-app-deployment -n todo-app
```

### Database Rollback (DynamoDB)

```bash
# Point-in-time recovery is enabled
# Use AWS Console or CLI to restore to specific time

aws dynamodb restore-table-to-point-in-time \
  --source-table-name todo-app-items \
  --target-table-name todo-app-items-backup \
  --restore-date-time 2024-05-08T10:00:00.000Z \
  --region us-east-1
```

### Configuration Rollback (Git)

```bash
# View git log
git log --oneline k8s/

# Revert specific commit
git revert <commit-hash>
git push origin main

# ArgoCD will automatically sync
```

## Environment Promotion

### Promote from Dev to Staging

```bash
# 1. Create staging branch
git checkout -b staging
git push origin staging

# 2. Update CircleCI to build on staging
# (configure in .circleci/config.yml)

# 3. Configure separate ArgoCD apps for each environment
kubectl apply -f argocd/application-staging.yaml

# 4. Deploy to staging cluster
# Pipeline builds image with staging tag
docker push your-registry/todo-app:staging

# 5. Verify in staging
```

### Promote from Staging to Production

```bash
# 1. Tag release version
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# 2. Pipeline automatically builds production image
docker push your-registry/todo-app:v1.0.0
docker push your-registry/todo-app:latest

# 3. Manual approval in CircleCI
# Review staging test results

# 4. Approve deployment
# Application auto-deployed to production

# 5. Monitor production metrics
```

## Maintenance Windows

### Planned Maintenance

```bash
# 1. Drain node (relocate pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# 2. Perform maintenance
aws ec2 reboot-instances --instance-ids <instance-id>

# 3. Uncordon node (allow pod scheduling)
kubectl uncordon <node-name>

# 4. Verify node is ready
kubectl get nodes
```

### Zero-Downtime Upgrade

```bash
# 1. Update cluster version (one minor version at a time)
aws eks update-cluster-version \
  --name todo-app-eks \
  --kubernetes-version 1.28 \
  --region us-east-1

# 2. Monitor update
aws eks describe-cluster --name todo-app-eks --query 'cluster.version'

# 3. Update node group version
aws eks update-nodegroup-version \
  --cluster-name todo-app-eks \
  --nodegroup-name todo-app-node-group \
  --kubernetes-version 1.28 \
  --region us-east-1

# 4. Monitor node updates (rolling update)
kubectl get nodes -w
```

## Cost Optimization

### Review Resource Usage

```bash
# Get pod resource requests vs actual usage
kubectl describe nodes

# View pod metrics
kubectl top pods -n todo-app

# View node capacity
kubectl describe node <node-name>
```

### Right-Size Instances

```bash
# Review current node instance types
aws eks describe-nodegroup \
  --cluster-name todo-app-eks \
  --nodegroup-name todo-app-node-group

# Update to smaller/larger instances if needed
aws eks update-nodegroup-config \
  --cluster-name todo-app-eks \
  --nodegroup-name todo-app-node-group \
  --scaling-config minSize=2,maxSize=8,desiredSize=3

# Change instance type (requires node group update)
```

### Reduce DynamoDB Costs

```bash
# Monitor DynamoDB usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value=todo-app-items \
  --start-time 2024-05-01T00:00:00Z \
  --end-time 2024-05-08T00:00:00Z \
  --period 86400 \
  --statistics Sum

# Already using PAY_PER_REQUEST billing (recommended)
```

## Disaster Recovery

### Backup Strategy

```bash
# Enable continuous backups for DynamoDB
aws dynamodb update-continuous-backups \
  --table-name todo-app-items \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

# Enable S3 versioning (already enabled)
aws s3api get-bucket-versioning --bucket todo-app-data
```

### Recovery Procedures

```bash
# DynamoDB restore
aws dynamodb restore-table-to-point-in-time \
  --source-table-name todo-app-items \
  --target-table-name todo-app-items-recovered \
  --restore-date-time 2024-05-08T15:00:00.000Z

# S3 recover deleted object
aws s3api list-object-versions --bucket todo-app-data --prefix "backup" | head -20

# Recover specific version
aws s3api get-object \
  --bucket todo-app-data \
  --key "backup/data.tar.gz" \
  --version-id "VxNP5e.qUZ_TbvTKDWiLQSF.h0K_CIg" \
  recovered-data.tar.gz
```

## Performance Tuning

### Container Resource Limits

```yaml
# Current limits in k8s/deployment.yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

# Increase if experiencing CPU throttling or OOM kills
# Decrease if resources being wasted
```

### Database Optimization

```bash
# Monitor DynamoDB throttling
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=todo-app-items \
  --start-time 2024-05-01T00:00:00Z \
  --end-time 2024-05-08T00:00:00Z \
  --period 3600 \
  --statistics Sum

# Add indexes if query patterns detected
```

### Network Optimization

```bash
# Use same AZ for lower latency
# Enable VPC endpoints for AWS services
# Review security group rules for unnecessary restrictions
```

## Common Deployment Issues

### Issue: Pods stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name> -n todo-app

# Common causes: insufficient resources, image pull error
# Check node resources
kubectl describe nodes

# Check image availability
kubectl get events -n todo-app
```

### Issue: CrashLoopBackOff

```bash
# View container logs
kubectl logs <pod-name> -n todo-app

# Check configuration
kubectl get configmap todo-app-config -n todo-app -o yaml

# Verify environment variables
kubectl set env deployment/todo-app-deployment --list -n todo-app
```

### Issue: High pod restart rate

```bash
# Check liveness probe settings
kubectl get deployment todo-app-deployment -n todo-app -o yaml | grep -A 10 "livenessProbe"

# Increase initial delay if app takes time to start
# View restart count
kubectl get pods -n todo-app
```

## Additional Resources

- [Kubernetes Deployment Best Practices](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [ArgoCD Deployment Patterns](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [Kubernetes Rolling Updates](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
