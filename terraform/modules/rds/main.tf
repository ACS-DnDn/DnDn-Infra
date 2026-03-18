locals {
  prefix = "${var.project}-${var.environment}"
}

# ── DB Subnet Group ───────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name        = "${lower(var.project)}-${lower(var.environment)}-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "RDS subnet group (Private 2A, 2C)"

  tags = {
    Name = "${local.prefix}-RDS-SUBNET-GROUP"
  }
}

# ── RDS Instance ──────────────────────────────────────────────────────────

resource "aws_db_instance" "main" {
  identifier = "${lower(var.project)}-${lower(var.environment)}-rds"

  engine         = "mariadb"
  engine_version = "10.11"
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username

  # 비밀번호는 RDS가 Secrets Manager에 자동 생성 · 저장
  manage_master_user_password = true

  port                 = 3306
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  multi_az            = true
  publicly_accessible = false

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  backup_retention_period = 7
  skip_final_snapshot     = false
  final_snapshot_identifier = "${lower(var.project)}-${lower(var.environment)}-rds-final"

  tags = {
    Name = "${local.prefix}-RDS"
  }
}
