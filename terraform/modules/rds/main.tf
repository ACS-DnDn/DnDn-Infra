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

# ── App DB Secret ──────────────────────────────────────────────────────────
# RDS 관리형 시크릿(master_user_secret)은 username/password만 포함 → Lambda 연결 불가
# host/port/dbname을 합쳐 Lambda용 전체 연결 정보 시크릿을 별도 생성

data "aws_secretsmanager_secret_version" "rds_managed" {
  secret_id = aws_db_instance.main.master_user_secret[0].secret_arn
}

resource "aws_secretsmanager_secret" "app_db" {
  name        = "${lower(var.project)}-${lower(var.environment)}-app-db"
  description = "Lambda용 DB 연결 정보 (host/port/username/password/dbname)"

  tags = {
    Name = "${local.prefix}-APP-DB-SECRET"
  }
}

resource "aws_secretsmanager_secret_version" "app_db" {
  secret_id = aws_secretsmanager_secret.app_db.id
  secret_string = jsonencode({
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    username = jsondecode(data.aws_secretsmanager_secret_version.rds_managed.secret_string)["username"]
    password = jsondecode(data.aws_secretsmanager_secret_version.rds_managed.secret_string)["password"]
    dbname   = var.db_name
  })
}
