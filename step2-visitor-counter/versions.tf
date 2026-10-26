terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 6.28 以上：Lambda 関数URLの新しい権限（invoked_via_function_url）に対応したバージョン
      version = ">= 6.28, < 7.0"
    }
    archive = {
      # Lambda のコードを zip にまとめるためのプロバイダー
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Owner     = var.owner
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
