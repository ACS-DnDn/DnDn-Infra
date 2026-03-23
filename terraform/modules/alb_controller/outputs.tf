output "controller_role_arn" {
  description = "ALB Controller IRSA Role ARN"
  value       = aws_iam_role.alb_controller.arn
}
