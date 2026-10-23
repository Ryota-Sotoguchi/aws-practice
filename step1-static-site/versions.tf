terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region

  # 作成するリソースすべてに自動でタグを付ける（課のアカウントで「誰のものか」がわかるように）
  default_tags {
    tags = {
      Owner     = var.owner
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
