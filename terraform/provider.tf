terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.16"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

   backend "s3" {
     bucket         = "todo-app-terraform-state"
     key            = "eks/terraform.tfstate"
     region         = "eu-central-1" # <--- CHANGE THIS TO eu-central-1
     encrypt        = true
     dynamodb_table = "terraform-locks"
   }
}

provider "aws" {
  region = var.aws_region # This stays ap-south-1 (from your variables)

  default_tags {
    tags = {
      Terraform   = "true"
      Environment = var.environment
      Project     = "todo-app-eks"
      ManagedBy   = "Terraform"
    }
  }
}
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.main.name
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.main.name
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
  # depends_on = [
  #   aws_eks_node_group.main
  # ]

data "aws_availability_zones" "available" {
  state = "available"
}
