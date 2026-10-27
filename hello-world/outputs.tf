output "bucket" {
  value = aws_s3_bucket.uploads.bucket
}

output "function_name" {
  value = aws_lambda_function.handler.function_name
}

output "log_group" {
  value = aws_cloudwatch_log_group.lambda.name
}
