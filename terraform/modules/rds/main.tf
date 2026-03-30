resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "${var.project_name}-${var.environment}-rds-credentials"
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id

  secret_string = jsonencode({
    RDS_HOST      = aws_db_instance.grp2dbinstance.address
    RDS_PORT      = "5432"
    RDS_USER      = var.db_username
    RDS_PASSWORD  = var.db_password
    RDS_DB_NAME   = aws_db_instance.grp2dbinstance.db_name
    RDS_TABLE_NAME = "products"
    RDS_SSLMODE   = "require"
  })
}

resource "aws_db_subnet_group" "rdssubnetgroup" {
  name       = "grp2-db-subnet-group"
  subnet_ids = var.subnets

  tags = {
    Name        = "grp2-db-subnet-group"
  }
  
}

resource "aws_db_instance" "grp2dbinstance" {
  identifier        = "grp2dbinstance"
  instance_class    = "db.t3.micro"
  engine            = "postgres"
  engine_version    = "17.6"
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true # Encryption at rest (AES-256, clé KMS managée par AWS)
  multi_az          = true
  db_name           = "grp2db"
  username          = var.db_username
  password          = var.db_password

  vpc_security_group_ids = [var.SG-DB]
  db_subnet_group_name   = aws_db_subnet_group.rdssubnetgroup.name
  skip_final_snapshot    = true

  # Performance Insights — gratuit sur db.t3.micro (7 jours de rétention)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = {
    Name = "grp2-rds-instance"
  }
}