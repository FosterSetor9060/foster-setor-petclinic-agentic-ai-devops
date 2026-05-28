variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "foster-petclinic-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to deploy subnets into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets used by RDS (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "eks_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_disk_size_gb" {
  description = "Root EBS volume size for each worker node (GiB)"
  type        = number
  default     = 20
}

variable "db_instance_class" {
  description = "RDS instance class — db.t4g.micro is free-tier eligible"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Name of the MySQL database to create"
  type        = string
  default     = "petclinic"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "petclinic_admin"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GiB (free tier: up to 20)"
  type        = number
  default     = 20
}

variable "openai_api_key" {
  description = "OpenAI API key — set via TF_VAR_openai_api_key or update the secret in AWS Secrets Manager after apply"
  type        = string
  default     = "REPLACE_ME"
  sensitive   = true
}
