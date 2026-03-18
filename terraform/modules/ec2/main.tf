locals {
  prefix     = "${lower(var.project)}-${lower(var.environment)}"
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── EC2 Security Group ─────────────────────────────────────────────────────

resource "aws_security_group" "ec2" {
  name        = "${local.prefix}-ec2-sg"
  description = "DEV EC2 app server (API/Worker/Reporter/Web + MariaDB)"
  vpc_id      = var.vpc_id

  # SSH (SSM 우선, SSH는 백업용)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  # HTTP/HTTPS (브라우저 → nginx)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  # API 포트 (Lambda scheduler-trigger → EC2 API)
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [var.lambda_sg_id]
    description     = "API from Lambda scheduler-trigger"
  }

  # MariaDB (Lambda enricher → EC2 MariaDB)
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.lambda_sg_id]
    description     = "MariaDB from Lambda enricher"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-ec2-sg"
  }
}

# ── EC2 IAM Role (Instance Profile) ───────────────────────────────────────
# IRSA 대신 EC2 Instance Profile에 앱 전체 권한 통합

resource "aws_iam_role" "ec2" {
  name = "${var.project}-${var.environment}-EC2-AppRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# SSM Session Manager (SSH 백업 + 패치 관리)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ec2_app" {
  name = "AppPolicy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # SQS — Worker (report-request 소비)
      {
        Effect = "Allow"
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = var.report_request_queue_arn
      },
      # SQS — Reporter (s3-event 소비)
      {
        Effect = "Allow"
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = var.s3_event_queue_arn
      },
      # SQS — API (report-request 전송)
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = var.report_request_queue_arn
      },
      # S3 — Worker/Reporter 보고서 읽기/쓰기
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/reports/*"
      },
      # S3 — Reporter canonical 읽기
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/canonical/*"
      },
      # Bedrock — Reporter 보고서 생성
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/*"
      },
      # sts:AssumeRole — Worker 고객 계정 접근
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::*:role/DnDnOpsAgentRole"
      },
      # Secrets Manager — DB 자격증명 조회 (Lambda enricher와 동일 방식)
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.db_secret_arn
      },
      # EventBridge Scheduler — API 스케줄 CRUD
      {
        Effect = "Allow"
        Action = [
          "scheduler:CreateSchedule",
          "scheduler:UpdateSchedule",
          "scheduler:DeleteSchedule",
          "scheduler:GetSchedule",
          "scheduler:ListSchedules",
        ]
        Resource = "arn:aws:scheduler:${local.region}:${local.account_id}:schedule/${var.scheduler_group_name}/*"
      },
      # iam:PassRole — Scheduler 생성 시 실행 Role 전달
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = var.scheduler_role_arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.environment}-EC2-InstanceProfile"
  role = aws_iam_role.ec2.name
}

# ── EC2 인스턴스 ───────────────────────────────────────────────────────────

resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  private_ip                  = var.private_ip
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                    = var.key_name != "" ? var.key_name : null

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "${local.prefix}-ec2-app"
  }
}
