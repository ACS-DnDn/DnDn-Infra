terraform {
  backend "s3" {
    bucket         = "dndn-prd-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "dndn-prd-tf-lock"
    encrypt        = true
  }
}
