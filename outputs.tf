output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "uploads_bucket_name" {
  value = aws_s3_bucket.uploads.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.documents.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.document_notifications.arn
}
output "document_api_url" {
  value = aws_apigatewayv2_api.document_api.api_endpoint
}