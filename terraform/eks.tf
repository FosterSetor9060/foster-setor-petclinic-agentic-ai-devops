# ─── IAM: Cluster Role ───────────────────────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  name = "foster-petclinic-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ─── IAM: Node Group Role ────────────────────────────────────────────────────

resource "aws_iam_role" "eks_nodes" {
  name = "foster-petclinic-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_readonly" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Allow nodes to read Secrets Manager (for RDS credentials and OpenAI key at pod level)
resource "aws_iam_role_policy" "eks_nodes_secrets" {
  name = "foster-petclinic-nodes-secrets-policy"
  role = aws_iam_role.eks_nodes.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:foster-petclinic/*"
    }]
  })
}

# ─── EKS Cluster ─────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]

  tags = {
    Name = var.cluster_name
  }
}

# ─── Security Group Rules (need cluster_security_group_id — added post-cluster) ───

# Allow EKS control plane to reach nodes on the kubelet port
resource "aws_security_group_rule" "nodes_ingress_control_plane_kubelet" {
  description              = "Control plane to node kubelet"
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# Allow EKS control plane to reach nodes on the webhook / metrics port range
resource "aws_security_group_rule" "nodes_ingress_control_plane_webhooks" {
  description              = "Control plane to node webhooks and extension API servers"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# ─── Launch Template ──────────────────────────────────────────────────────────
# Attaches both our custom SG and the EKS-managed cluster SG to every node.
# The cluster SG carries all default EKS communication rules.

resource "aws_launch_template" "eks_nodes" {
  name_prefix = "foster-petclinic-node-"
  description = "Launch template for foster-petclinic EKS Graviton worker nodes"

  # Do NOT set instance_type here — it is declared on the node group so that
  # managed scaling works correctly and the type can be overridden via variables.

  vpc_security_group_ids = [
    aws_security_group.eks_nodes.id,
    aws_eks_cluster.main.vpc_config[0].cluster_security_group_id,
  ]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.node_disk_size_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "foster-petclinic-node"
      project = "foster-petclinic"
      owner   = "foster-setor"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name    = "foster-petclinic-node-volume"
      project = "foster-petclinic"
      owner   = "foster-setor"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── EKS Managed Node Group ──────────────────────────────────────────────────

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "foster-petclinic-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.public[*].id

  # AL2_x86_64 — Amazon Linux 2 for x86_64 (t3) instances
  ami_type       = "AL2_x86_64"
  instance_types = [var.node_instance_type]
  capacity_type  = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly,
    aws_security_group_rule.nodes_ingress_control_plane_kubelet,
    aws_security_group_rule.nodes_ingress_control_plane_webhooks,
  ]

  tags = {
    Name = "foster-petclinic-nodes"
  }
}
