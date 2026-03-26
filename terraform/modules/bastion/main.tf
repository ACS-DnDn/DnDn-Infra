locals {
  prefix = "${var.project}-${var.environment}"
}

# ── Amazon Linux 2023 최신 AMI ────────────────────────────────────────────

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ── Bastion IAM Role (EKS kubectl + ECR pull) ────────────────────────────

resource "aws_iam_role" "bastion" {
  name = "${local.prefix}-Bastion-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "bastion_eks" {
  name = "EKSAccessPolicy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.prefix}-Bastion-Profile"
  role = aws_iam_role.bastion.name
}

# ── Bastion EC2 ───────────────────────────────────────────────────────────

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  user_data = <<-USERDATA
    #!/bin/bash
    # kubectl 설치
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl && mv kubectl /usr/local/bin/
  USERDATA

  tags = {
    Name = "${local.prefix}-BASTION"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# ── Elastic IP (고정 IP) ──────────────────────────────────────────────────

resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name = "${local.prefix}-BASTION-EIP"
  }
}

resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}
