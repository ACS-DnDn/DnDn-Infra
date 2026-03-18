output "instance_id" {
  description = "Bastion EC2 Instance ID"
  value       = aws_instance.bastion.id
}

output "public_ip" {
  description = "Bastion 퍼블릭 IP (유동)"
  value       = aws_instance.bastion.public_ip
}
