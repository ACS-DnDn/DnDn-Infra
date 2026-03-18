output "bastion_sg_id" {
  description = "Bastion Host SG ID"
  value       = aws_security_group.bastion.id
}

output "alb_sg_id" {
  description = "ALB SG ID"
  value       = aws_security_group.alb.id
}

output "node_sg_id" {
  description = "EKS Node 추가 SG ID"
  value       = aws_security_group.node.id
}

output "lambda_sg_id" {
  description = "Lambda SG ID"
  value       = aws_security_group.lambda.id
}

output "rds_sg_id" {
  description = "RDS SG ID"
  value       = aws_security_group.rds.id
}
