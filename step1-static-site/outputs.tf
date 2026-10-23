output "site_url" {
  description = "ブラウザで開くURL"
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "bucket_name" {
  description = "作成されたS3バケット名"
  value       = aws_s3_bucket.site.id
}

output "distribution_id" {
  description = "CloudFrontディストリビューションID（キャッシュ削除などで使う）"
  value       = aws_cloudfront_distribution.site.id
}
