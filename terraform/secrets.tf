# ─── RDS Credentials ─────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "foster-petclinic/rds-credentials"
  description             = "MySQL credentials for the foster-petclinic RDS instance"
  recovery_window_in_days = 7

  tags = {
    Name = "foster-petclinic-rds-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id

  secret_string = jsonencode({
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
    username = aws_db_instance.main.username
    password = random_password.db_password.result
    # JDBC URL for Spring Boot services using the mysql profile
    jdbc_url = "jdbc:mysql://${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}?allowPublicKeyRetrieval=true&useSSL=false"
  })
}

# ─── OpenAI API Key ───────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "openai_api_key" {
  name                    = "foster-petclinic/openai-api-key"
  description             = "OpenAI API key for the genai-service. Update via console or CLI after apply."
  recovery_window_in_days = 7

  tags = {
    Name = "foster-petclinic-openai-api-key"
  }
}

resource "aws_secretsmanager_secret_version" "openai_api_key" {
  secret_id = aws_secretsmanager_secret.openai_api_key.id

  secret_string = jsonencode({
    OPENAI_API_KEY = var.openai_api_key
  })

  # Prevent Terraform from reverting a key that was updated manually in the console
  lifecycle {
    ignore_changes = [secret_string]
  }
}
