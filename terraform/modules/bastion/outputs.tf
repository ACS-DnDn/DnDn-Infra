output "instance_id" {
  description = "Bastion EC2 Instance ID"
  value       = aws_instance.bastion.id
}

output "public_ip" {
  description = "Bastion Elastic IP (고정)"
  value       = aws_eip.bastion.public_ip
}

output "role_arn" {
  description = "Bastion IAM Role ARN (EKS access entry에 사용)"
  value       = aws_iam_role.bastion.arn
}
