output "instance_id" {
  description = "EC2 인스턴스 ID"
  value       = aws_instance.app.id
}

output "private_ip" {
  description = "EC2 사설 IP — Lambda API_INTERNAL_URL에 사용"
  value       = aws_instance.app.private_ip
}

output "public_ip" {
  description = "EC2 공인 IP — SSH 접속 및 브라우저 접근"
  value       = aws_instance.app.public_ip
}

output "ec2_sg_id" {
  description = "EC2 Security Group ID"
  value       = aws_security_group.ec2.id
}
