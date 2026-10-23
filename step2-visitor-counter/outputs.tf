output "site_url" {
  description = "ブラウザで開くURL"
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "counter_api_url" {
  description = "訪問者カウンターAPI（Lambda 関数URL）"
  value       = aws_lambda_function_url.counter.function_url
}

output "table_name" {
  description = "カウントを保存している DynamoDB テーブル名"
  value       = aws_dynamodb_table.counter.name
}

output "distribution_id" {
  description = "CloudFrontディストリビューションID（キャッシュ削除などで使う）"
  value       = aws_cloudfront_distribution.site.id
}
