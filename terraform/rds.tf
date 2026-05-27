# ─── Password ────────────────────────────────────────────────────────────────

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}?"
  # Exclude characters that can break JDBC connection strings
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

# ─── Subnet Group ────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name        = "foster-petclinic-db-subnet-group"
  description = "Private subnets for RDS MySQL"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "foster-petclinic-db-subnet-group"
  }
}

# ─── Parameter Group ─────────────────────────────────────────────────────────

resource "aws_db_parameter_group" "mysql8" {
  name        = "foster-petclinic-mysql8"
  family      = "mysql8.0"
  description = "Custom parameter group for foster-petclinic MySQL 8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = {
    Name = "foster-petclinic-mysql8"
  }
}

# ─── RDS Instance ────────────────────────────────────────────────────────────

resource "aws_db_instance" "main" {
  identifier = "foster-petclinic-db"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100 # autoscaling ceiling
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.mysql8.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = false
  port                = 3306

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection     = false # set to true before production go-live
  skip_final_snapshot     = true  # change to false and set final_snapshot_identifier for production

  tags = {
    Name = "foster-petclinic-db"
  }

  depends_on = [aws_db_subnet_group.main]
}
