variable "region" {
  description = "S3バケットを作るリージョン（CloudFront自体はグローバル）"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "リソース名やタグに使うプロジェクト名（英小文字・数字・ハイフン）"
  type        = string
  default     = "handson-static-site"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project))
    error_message = "project は英小文字・数字・ハイフンの3〜30文字にしてください。"
  }
}

variable "owner" {
  description = "Owner タグに入れる名前（課のアカウントで誰のリソースかわかるように）"
  type        = string
}
