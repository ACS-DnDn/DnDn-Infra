output "bucket_name" {
  description = "S3 버킷 이름"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "S3 버킷 ARN"
  value       = aws_s3_bucket.main.arn
}
