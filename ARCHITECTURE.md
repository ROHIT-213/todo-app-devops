# Architecture Documentation

## System Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Developers                               │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│                  GitHub Repository                          │
│           (Source Code + K8s Manifests)                     │
└─────────────┬───────────────────────────────────────────────┘
              │ (Webhook)
              ▼
┌─────────────────────────────────────────────────────────────┐
│                   CircleCI Pipeline                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Build   │→ │   Test   │→ │  Push to │→ │ Update   │   │
│  │   Code   │  │          │  │   ECR    │  │ Manifest │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│              AWS ECR (Container Registry)                   │
│                  Docker Images                              │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│                 AWS EKS Cluster                             │
│  ┌────────────────────────────────────────────────────────┐│
│  │              ArgoCD Operator                           ││
│  │  (Watches GitHub for manifest changes)                ││
│  └────────────┬─────────────────────────────────────────┘│
│               │                                            │
│               ▼                                            │
│  ┌────────────────────────────────────────────────────────┐│
│  │         Kubernetes Namespaces                         ││
│  │  ┌──────────────┐  ┌──────────────────┐              ││
│  │  │  todo-app    │  │  argocd          │              ││
│  │  │  (Deployment)│  │  (GitOps Engine) │              ││
│  │  └──────────────┘  └──────────────────┘              ││
│  │                                                        ││
│  │  - 3 Pod Replicas                                    ││
│  │  - Auto-scaling (HPA)                               ││
│  │  - Rolling updates                                  ││
│  │  - Health checks                                    ││
│  └────────────────────────────────────────────────────────┘│
│  ┌────────────────────────────────────────────────────────┐│
│  │              Services & Networking                     ││
│  │  - LoadBalancer Service (port 80→3000)               ││
│  │  - AWS NLB (Network Load Balancer)                   ││
│  │  - Security Groups                                   ││
│  └────────────────────────────────────────────────────────┘│
└─────────────┬───────────────────────────────────────────────┘
              │
    ┌─────────┼─────────┐
    │         │         │
    ▼         ▼         ▼
┌────────┐ ┌──────────┐ ┌────────────────┐
│ Users  │ │ DynamoDB │ │   S3 Buckets   │
│Browser │ │ (Data)   │ │  (Backups/Logs)│
└────────┘ └──────────┘ └────────────────┘
```

## Component Details

### 1. GitHub Repository
- **Purpose**: Version control and source of truth for deployments
- **Contains**:
  - Application source code
  - Kubernetes manifests
  - Terraform infrastructure code
  - CircleCI configuration
  - ArgoCD configuration

### 2. CircleCI Pipeline
- **Purpose**: Continuous Integration and Continuous Deployment
- **Jobs**:
  1. **Build**: Compile code, run tests
  2. **Push Image**: Build Docker image, push to ECR
  3. **Update Manifests**: Update Kubernetes deployment manifest
  4. **Manual Approval**: Hold for human review
  5. **Deploy**: Sync application via ArgoCD

### 3. AWS ECR (Elastic Container Registry)
- **Purpose**: Container image repository
- **Stores**: Docker images for todo-app
- **Tagging**: 
  - `latest` - Most recent build
  - Git SHA - Specific commit version

### 4. AWS EKS Cluster
- **Purpose**: Managed Kubernetes cluster
- **Configuration**:
  - Version: 1.27
  - Node Group: 3-10 t3.medium instances
  - Multi-AZ deployment
  - Auto-scaling enabled

### 5. Kubernetes Deployments
- **todo-app Deployment**:
  - 3 replicas minimum
  - RollingUpdate strategy
  - Resource limits: 512Mi memory, 500m CPU
  - Health checks: Liveness & Readiness probes
  - Auto-scaling: 10 pods maximum

- **ArgoCD Deployment**:
  - GitOps engine
  - Watches GitHub for changes
  - Auto-syncs manifests
  - Manages application state

### 6. AWS DynamoDB
- **Purpose**: NoSQL database for application data
- **Tables**:
  - `todo-app-items`: User todos (hash: user_id, range: todo_id)
  - `todo-app-items-sessions`: User sessions
- **Features**:
  - On-demand billing
  - Point-in-time recovery
  - TTL for automatic cleanup
  - Stream specification for real-time updates

### 7. AWS S3
- **Purpose**: Object storage for backups and data
- **Buckets**:
  - `todo-app-data-{account}`: Application backups
  - `todo-app-terraform-state-{account}`: Terraform state
- **Features**:
  - Versioning enabled
  - Encryption at rest
  - Lifecycle policies
  - Public access blocked

## Network Architecture

### VPC Configuration
```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.101-103.0/24)
│   ├── NAT Gateway (AZ1)
│   ├── NAT Gateway (AZ2)
│   └── NAT Gateway (AZ3)
│
└── Private Subnets (10.0.1-3.0/24)
    ├── EKS Nodes (AZ1)
    ├── EKS Nodes (AZ2)
    └── EKS Nodes (AZ3)
```

### Security Groups
1. **Master Security Group**: 
   - Inbound: 443 from node security group
   - Outbound: All

2. **Node Security Group**:
   - Inbound: All from node security group
   - Inbound: 1025-65535 from master
   - Inbound: 80 from 0.0.0.0/0
   - Inbound: 443 from 0.0.0.0/0
   - Outbound: All to 0.0.0.0/0

## Data Flow

### 1. Application Deployment Flow
```
1. Developer commits to main branch
2. GitHub sends webhook to CircleCI
3. CircleCI:
   - Builds application
   - Runs tests
   - Builds Docker image
   - Pushes to ECR
   - Updates Kubernetes manifest in git
4. ArgoCD detects changes
5. ArgoCD syncs manifests to EKS
6. Kubernetes:
   - Pulls image from ECR
   - Creates/updates pods
   - Routes traffic through LoadBalancer
```

### 2. Application Request Flow
```
1. User browser
2. AWS Network Load Balancer
3. Kubernetes Service (port 80)
4. Pod container (port 3000)
5. React application
   - Reads/writes to DynamoDB
   - Stores backups in S3
```

### 3. Data Persistence Flow
```
Application
    ↓
DynamoDB
    ↓
    ├→ Real-time data (active todos)
    ├→ User sessions
    └→ Point-in-time backups (enabled)
    
S3
    ↓
    ├→ Backup snapshots
    ├→ Export data
    └→ Version history
```

## High Availability & Disaster Recovery

### HA Configuration
1. **Multi-AZ**: Pods distributed across 3 availability zones
2. **Auto-scaling**: Scales from 3 to 10 pods based on CPU/memory
3. **Load Balancing**: AWS NLB distributes traffic
4. **Health Checks**: Automatic pod restart on failure
5. **Rolling Updates**: Zero-downtime deployments

### Disaster Recovery
1. **Database Backup**: DynamoDB point-in-time recovery
2. **State Backup**: Terraform state versioned in S3
3. **Application Rollback**: Kubernetes rollout history
4. **Configuration Recovery**: Git history for manifests

## Security Architecture

### Authentication & Authorization
1. **AWS IAM**: User authentication
2. **Kubernetes RBAC**: Pod-level authorization
3. **IRSA**: Service account to IAM role mapping
4. **GitHub Tokens**: Git repository access

### Data Security
1. **Encryption at Rest**: S3 and DynamoDB encryption
2. **Encryption in Transit**: TLS for all communications
3. **Network Isolation**: Private subnets for nodes
4. **Pod Security**: Non-root containers, read-only filesystem

### Secrets Management
1. **GitHub Secrets**: CircleCI environment variables
2. **Kubernetes Secrets**: Credentials in argocd namespace
3. **AWS Secrets Manager**: Optional for additional secrets

## Monitoring & Observability

### CloudWatch Logs
- EKS Cluster Logs (api, audit, authenticator, controller, scheduler)
- Application logs from pods
- 7-day retention

### Metrics
- Kubernetes metrics: CPU, memory per pod/node
- CloudWatch metrics: EC2, DynamoDB, S3 usage
- Custom application metrics (optional)

### Alerting
- Pod restart alerts
- Node failure alerts
- DynamoDB throttling alerts
- CPU/memory threshold alerts

## Cost Optimization

### Compute
- EC2 Auto Scaling: Scale down during off-hours
- Spot instances: Optional for dev/test environments
- Right-sizing: Monitor actual usage

### Storage
- DynamoDB: On-demand pricing (pay per request)
- S3: Lifecycle policies to archive old data
- EBS: Delete unused volumes

### Network
- VPC Endpoints: Reduce data transfer costs
- NAT Gateway optimization
- Load balancer optimization

## Scalability Considerations

### Horizontal Scaling
- Auto-scaling groups for EC2 nodes
- Kubernetes HPA for pods
- Load balancer scales automatically

### Vertical Scaling
- Increase node instance types if needed
- Increase pod resource requests/limits
- Database optimization (indexes)

### Performance Optimization
- Application caching
- Database query optimization
- CDN for static assets (optional)
- Connection pooling

## Technology Stack Summary

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| Application | React | 18.0+ | Frontend framework |
| Container | Docker | Latest | Containerization |
| Orchestration | Kubernetes | 1.27 | Container orchestration |
| GitOps | ArgoCD | Latest | Deployment automation |
| CI/CD | CircleCI | Latest | Pipeline automation |
| IaC | Terraform | 1.0+ | Infrastructure provisioning |
| Cloud | AWS | Latest | Cloud provider |
| Container Registry | ECR | Latest | Image repository |
| Database | DynamoDB | Latest | NoSQL database |
| Storage | S3 | Latest | Object storage |
| Load Balancer | NLB | Latest | Network load balancing |

This architecture provides a production-ready, scalable, and secure platform for deploying containerized applications on AWS with full GitOps automation.
