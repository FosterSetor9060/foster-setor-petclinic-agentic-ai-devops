# ─── VPC ─────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the foster-petclinic VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (EKS nodes)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (RDS)"
  value       = aws_subnet.private[*].id
}

# ─── EKS ─────────────────────────────────────────────────────────────────────

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint for the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the EKS cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "eks_cluster_security_group_id" {
  description = "EKS-managed cluster security group ID (applied to control plane and nodes)"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl for the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# ─── ECR ─────────────────────────────────────────────────────────────────────

output "ecr_repository_urls" {
  description = "Map of service name → ECR repository URL"
  value       = { for name, repo in aws_ecr_repository.services : name => repo.repository_url }
}

output "ecr_registry_id" {
  description = "AWS account ID hosting the ECR registries"
  value       = values(aws_ecr_repository.services)[0].registry_id
}

# ─── RDS ─────────────────────────────────────────────────────────────────────

output "rds_endpoint" {
  description = "RDS instance hostname (without port)"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "Name of the MySQL database"
  value       = aws_db_instance.main.db_name
}

# ─── Secrets Manager ─────────────────────────────────────────────────────────

output "secret_arn_rds_credentials" {
  description = "ARN of the RDS credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "secret_arn_openai_api_key" {
  description = "ARN of the OpenAI API key secret in Secrets Manager"
  value       = aws_secretsmanager_secret.openai_api_key.arn
}
