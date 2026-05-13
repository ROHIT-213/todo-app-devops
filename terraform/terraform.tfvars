# Terraform configuration values
# Copy this to terraform.tfvars and update with your values

aws_region = "ap-south-1"
environment = "production"
project_name = "todo-app"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS Configuration
cluster_name = "todo-app-eks"
cluster_version = "1.27"
node_group_desired_size = 3
node_group_min_size = 3
node_group_max_size = 10
node_instance_types = ["t3.medium"]

# Features
enable_argocd = true
enable_monitoring = true

# Registry
container_registry = "docker.io"
image_pull_policy = "IfNotPresent"

# DynamoDB
dynamodb_table_name = "todo-app-items"

# S3
s3_bucket_name = "todo-app-data"

# Tags
tags = {
  Environment = "production"
  Project     = "todo-app"
  ManagedBy   = "Terraform"
}
