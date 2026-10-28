terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# --- Lambda ---

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/lambda.zip"
}

resource "aws_iam_role" "lambda" {
  name = "${var.prefix}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Created explicitly so `terraform destroy` cleans it up
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.prefix}-handler"
  retention_in_days = 7
}

resource "aws_lambda_function" "handler" {
  function_name    = "${var.prefix}-handler"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  depends_on = [
    aws_iam_role_policy_attachment.logs,
    aws_cloudwatch_log_group.lambda,
  ]
}

# --- Failure destination ---

resource "aws_sqs_queue" "failures" {
  name = "${var.prefix}-failures"
}

# Lambda delivers to the destination using the function's own role
resource "aws_iam_role_policy" "send_failures" {
  name = "send-failures"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.failures.arn
    }]
  })
}

resource "aws_lambda_function_event_invoke_config" "handler" {
  function_name = aws_lambda_function.handler.function_name

  # No retries, so failures show up in the queue immediately (default is 2)
  maximum_retry_attempts = 0

  destination_config {
    on_failure {
      destination = aws_sqs_queue.failures.arn
    }
  }

  depends_on = [aws_iam_role_policy.send_failures]
}

# --- S3 trigger ---

resource "aws_s3_bucket" "uploads" {
  # Bucket names are global; the account ID keeps them unique
  bucket        = "${var.prefix}-uploads-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_iam_role_policy" "read_uploads" {
  name = "read-uploads"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
}

resource "aws_lambda_permission" "s3" {
  statement_id   = "AllowS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.handler.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.uploads.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.handler.arn
    events              = ["s3:ObjectCreated:Put"]
  }

  depends_on = [aws_lambda_permission.s3]
}
