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
    aws_iam_role_policy_attachment.eks_ebs_csi_policy                 //added for EBS CSI Driver permissions (gemini)
  ]
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
# resource "kubernetes_storage_class_v1" "gp2" {
#   metadata {
#     name = "gp2"
#   }

#   storage_provisioner = "ebs.csi.aws.com"
#   volume_binding_mode = "WaitForFirstConsumer"
#   reclaim_policy      = "Delete"

#   parameters = {
#     type = "gp3" # Upgrades your underlying disk to fast, cost-efficient GP3 volumes automatically
#   }

#   depends_on = [
#     aws_eks_node_group.main
#   ]
# }

# 1. Create a Trust Policy letting the EKS Add-on assume this role (gemini)
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

# 2. Create the IAM Role for the Add-on(gemini)
resource "aws_iam_role" "eks_ebs_csi_driver" {
  name               = "${var.cluster_name}-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}
# 3. Attach the official AWS EBS Driver Policy to this new role (gemini)
resource "aws_iam_role_policy_attachment" "eks_ebs_csi_driver_attach" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks_ebs_csi_driver.name
}                                                                                 #gemini
# Deploy the native AWS EBS CSI Driver Add-on
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  # addon_version               = "v1.30.0-eksbuild.1" # Use your current version string
  resolve_conflicts_on_update = "OVERWRITE"          # <--- ADD THIS LINE
  resolve_conflicts_on_create = "OVERWRITE"          # <--- ADD THIS LINE (if using AWS provider v5.x)
  
  service_account_role_arn    = aws_iam_role.eks_ebs_csi_driver.arn  #added by gemini
  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.eks_ebs_csi_driver_attach        #added by gemini
  ]
}
#code end of gemini suggestions for EBS CSI Driver and StorageClass
