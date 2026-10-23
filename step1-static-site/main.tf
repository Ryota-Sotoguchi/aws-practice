############################################
# S3：サイトのファイル置き場（非公開）
############################################

resource "aws_s3_bucket" "site" {
  # 末尾にランダムな文字列が付き、世界で一意なバケット名になる
  bucket_prefix = "${var.project}-"

  # terraform destroy でファイルごと削除できるようにする（学習用の設定）
  force_destroy = true
}

# バケットは完全非公開。アクセスはCloudFront経由だけに絞る
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

############################################
# サイトのファイルをアップロード
############################################

locals {
  site_dir = "${path.module}/site"

  content_types = {
    html = "text/html; charset=utf-8"
    css  = "text/css; charset=utf-8"
    js   = "application/javascript; charset=utf-8"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    jpeg = "image/jpeg"
    svg  = "image/svg+xml"
    ico  = "image/x-icon"
    txt  = "text/plain; charset=utf-8"
  }
}

resource "aws_s3_object" "site_files" {
  for_each = fileset(local.site_dir, "**")

  bucket = aws_s3_bucket.site.id
  key    = each.value
  source = "${local.site_dir}/${each.value}"

  # ファイルの中身が変わったら再アップロードされる
  etag = filemd5("${local.site_dir}/${each.value}")

  content_type = lookup(
    local.content_types,
    lower(element(split(".", each.value), length(split(".", each.value)) - 1)),
    "application/octet-stream"
  )
}

############################################
# CloudFront：HTTPSで配信する入り口
############################################

# OAC（Origin Access Control）：CloudFrontだけがS3を読めるようにする仕組み
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project}-oac"
  description                       = "OAC for ${var.project}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# AWSが用意している「静的ファイル向け」キャッシュ設定
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = var.project
  default_root_object = "index.html"
  is_ipv6_enabled     = true

  # 北米・欧州・アジア（日本含む）のエッジを使用。無料枠の範囲なら料金は変わらない
  price_class = "PriceClass_200"

  origin {
    origin_id                = "s3-site"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # 存在しないパスは 404.html を返す
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # 独自ドメインなし：*.cloudfront.net の標準証明書でHTTPS化（Route 53・ACM不要）
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

############################################
# バケットポリシー：このCloudFrontからの読み取りだけを許可
############################################

data "aws_iam_policy_document" "site" {
  statement {
    sid       = "AllowCloudFrontReadOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json

  depends_on = [aws_s3_bucket_public_access_block.site]
}
