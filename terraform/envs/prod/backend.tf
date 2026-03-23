terraform {
  backend "s3" {
    bucket         = "dndn-prd-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "dndn-prd-tf-lock"
  }
}

# DynamoDB 테이블은 terraform init 전에 수동 생성 필요:
# aws dynamodb create-table \
#   --table-name dndn-prd-tf-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region ap-northeast-2
