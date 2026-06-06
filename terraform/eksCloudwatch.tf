resource "aws_eks_cluster" "main" {
  name            = var.cluster_name
  version         = var.cluster_version
  role_arn        = aws_iam_role.eks_cluster_role.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_master.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller
  ]

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "eks_ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"       //added by gemini
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.private[*].id
  version         = var.cluster_version

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  instance_types = var.node_instance_types

  update_config {
    max_unavailable_percentage = 25
  }

  tags = {
    Name = "${var.project_name}-node-group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
    aws_iam_role_policy_attachment.eks_ssm_policy,
    aws_iam_role_policy.node_dynamodb_s3_policy,
    aws_iam_role_policy_attachment.eks_cloudwatch_agent_policy, //added for CloudWatch Agent permissions (gemini)
    aws_iam_role_policy_attachment.eks_ebs_csi_policy                 //added for EBS CSI Driver permissions (gemini)
  ]
}
#gemini 06-jun-26 
# Attach CloudWatch Agent Policy to Node Role so it can ship container metrics
resource "aws_iam_role_policy_attachment" "eks_cloudwatch_agent_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_node_role.name
}
# CloudWatch Log Group for EKS Cluster Logs
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-eks-logs"
  }
}
#suggested code by gemini to create the gp2 StorageClass mapped to the AWS EBS CSI Driver, which is required for dynamic provisioning of EBS volumes in EKS clusters. This allows Kubernetes to automatically create and manage EBS volumes for persistent storage when using the gp2 StorageClass.
# Create the gp2 StorageClass mapped to the AWS EBS CSI Driver
resource "kubernetes_storage_class_v1" "gp2" {
  metadata {
    name = "gp2"
  }

  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  reclaim_policy      = "Delete"

  parameters = {
    type = "gp3" # Upgrades your underlying disk to fast, cost-efficient GP3 volumes automatically
  }

  depends_on = [
    aws_eks_node_group.main
  ]
}

# Deploy the native AWS EBS CSI Driver Add-on
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"

  # Adds the necessary permissions link so the add-on doesn't time out
  service_account_role_arn = aws_iam_role.eks_node_role.arn
  
  depends_on = [
    aws_eks_node_group.main
  ]
}
#code end of gemini suggestions for EBS CSI Driver and StorageClass



#gemini 06-jun-26
resource "aws_cloudwatch_dashboard" "eks_dashboard" {
  dashboard_name = "${var.project_name}-eks-insights"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: EKS Cluster Node Count
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ContainerInsights", "node_count", "ClusterName", var.cluster_name ]
          ]
          period  = 60
          stat    = "Average"
          region  = "ap-south-1"
          title   = "Active EKS Worker Nodes"
          view    = "singleValue"
        }
      },
      # Widget 2: Cluster CPU & Memory Utilization
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name ],
            [ ".", "node_memory_utilization", ".", "." ]
          ]
          period  = 60
          stat    = "Average"
          region  = "ap-south-1"
          title   = "Cluster Infrastructure Utilization Baselines"
          view    = "timeSeries"
          stacked = false
        }
      },
      # Widget 3: Individual Pod Failed Phases (Triggers alongside your Prometheus metrics)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          metrics = [
            [ "AWS/ContainerInsights", "pod_number_of_container_restarts", "ClusterName", var.cluster_name ]
          ]
          period  = 60
          stat    = "Sum"
          region  = "ap-south-1"
          title   = "EKS Pod Container Restart Rates (CrashLoop Tracking)"
          view    = "timeSeries"
        }
      }
    ]
  })
}

# Deploys CloudWatch Container Insights to collect cluster metrics automatically
resource "aws_eks_addon" "cloudwatch_insights" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "amazon-cloudwatch-observability"

  depends_on = [
    aws_eks_node_group.main
  ]
}