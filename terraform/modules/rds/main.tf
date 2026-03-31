locals {
  prefix             = "${var.project}-${var.environment}"
  app_db_secret_name = coalesce(var.app_db_secret_name, "${lower(var.project)}-${lower(var.environment)}-app-db")
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

  port                   = 3306
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  multi_az            = true
  publicly_accessible = false

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  backup_retention_period   = 7
  skip_final_snapshot       = false
  final_snapshot_identifier = "${lower(var.project)}-${lower(var.environment)}-rds-final"

  tags = {
    Name = "${local.prefix}-RDS"
  }

  lifecycle {
    # 운영에서 수동으로 managed password를 비활성화한 상태를 그대로 유지한다.
    ignore_changes = [manage_master_user_password]
  }
}

# ── App DB Secret ──────────────────────────────────────────────────────────
# 운영 기준은 app-db secret이다.
# 현재 secret 값을 기준으로 host/port/dbname만 동기화한다.

data "aws_secretsmanager_secret_version" "app_db_existing" {
  secret_id = local.app_db_secret_name
}

resource "aws_secretsmanager_secret" "app_db" {
  name        = local.app_db_secret_name
  description = "Lambda용 DB 연결 정보 (host/port/username/password/dbname)"

  tags = {
    Name = "${local.prefix}-APP-DB-SECRET"
  }
}

resource "aws_secretsmanager_secret_version" "app_db" {
  secret_id = aws_secretsmanager_secret.app_db.id
  secret_string = jsonencode(
    merge(
      jsondecode(data.aws_secretsmanager_secret_version.app_db_existing.secret_string),
      {
        host   = aws_db_instance.main.address
        port   = aws_db_instance.main.port
        dbname = var.db_name
      }
    )
  )
}
