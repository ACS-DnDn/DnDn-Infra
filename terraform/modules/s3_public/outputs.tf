output "bucket_name" {
  description = "퍼블릭 S3 버킷 이름"
  value       = aws_s3_bucket.public.id
}

output "bucket_arn" {
  description = "퍼블릭 S3 버킷 ARN"
  value       = aws_s3_bucket.public.arn
}

output "cfn_base_url" {
  description = "고객 배포용 CFN 템플릿 base URL"
  value       = "https://${aws_s3_bucket.public.bucket}.s3.${data.aws_region.current.name}.amazonaws.com/cfn"
}
