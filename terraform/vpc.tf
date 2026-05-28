# ─── VPC ─────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "foster-petclinic-vpc"
  }
}

# ─── Subnets ─────────────────────────────────────────────────────────────────

# Public subnets — EKS worker nodes and ALB ingress
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "foster-petclinic-public-${var.availability_zones[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    # Required for the AWS Load Balancer Controller to discover subnets for public ALBs
    "kubernetes.io/role/elb" = "1"
  }
}

# Private subnets — RDS only; no internet route
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "foster-petclinic-private-${var.availability_zones[count.index]}"
  }
}

# ─── Internet Gateway & Route Tables ─────────────────────────────────────────

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "foster-petclinic-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "foster-petclinic-public-rt"
  }
}

# Private route table has no internet route — VPC-local traffic only
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "foster-petclinic-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ─── Security Groups ──────────────────────────────────────────────────────────

# EKS worker nodes — base rules; control-plane ↔ node rules are added in eks.tf
# after the cluster (and its managed cluster_security_group_id) exists.
resource "aws_security_group" "eks_nodes" {
  name        = "foster-petclinic-eks-nodes-sg"
  description = "Additional security group attached to EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  # Node-to-node communication (pod networking, cni)
  ingress {
    description = "Allow all traffic between worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Unrestricted outbound — nodes pull images from ECR, talk to the API server, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                        = "foster-petclinic-eks-nodes-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# RDS — only accepts MySQL connections originating from the EKS node SG
resource "aws_security_group" "rds" {
  name        = "foster-petclinic-rds-sg"
  description = "RDS MySQL - inbound 3306 from EKS nodes only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EKS worker nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "foster-petclinic-rds-sg"
  }
}
