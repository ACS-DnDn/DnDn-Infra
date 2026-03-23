locals {
  prefix = "${var.project}-${var.environment}"
}

# ── Bastion SG ───────────────────────────────────────────────────────────────

resource "aws_security_group" "bastion" {
  name        = "${local.prefix}-SG-BASTION"
  description = "Bastion Host - SSH access"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-SG-BASTION"
  }
}

# ── ALB SG ───────────────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${local.prefix}-SG-ALB"
  description = "ALB - HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-SG-ALB"
  }
}

# ── EKS Node SG ──────────────────────────────────────────────────────────────

resource "aws_security_group" "node" {
  name        = "${local.prefix}-SG-NODE"
  description = "EKS Node - traffic from ALB and inter-pod"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NodePort traffic from ALB"
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Pod-to-Pod (same SG)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-SG-NODE"
  }
}

# ── Lambda SG ────────────────────────────────────────────────────────────────

resource "aws_security_group" "lambda" {
  name        = "${local.prefix}-SG-LAMBDA"
  description = "Lambda - outbound to RDS and AWS services"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-SG-LAMBDA"
  }
}

# ── RDS SG ───────────────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${local.prefix}-SG-RDS"
  description = "RDS - MySQL access from Lambda and EKS Node"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from Lambda"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  ingress {
    description     = "MySQL from EKS Node"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.node.id]
  }

  ingress {
    description     = "MySQL from Bastion"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-SG-RDS"
  }
}
