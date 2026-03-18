terraform {
  backend "s3" {
    bucket         = "dndn-prd-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
encrypt        = true
  }
}
