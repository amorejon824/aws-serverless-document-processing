resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name_prefix}-frontend-${random_id.suffix.hex}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-frontend"
  })
}

resource "aws_s3_bucket" "uploads" {
  bucket = "${local.name_prefix}-uploads-${random_id.suffix.hex}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-uploads"
  })
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "documents" {
  name         = "${local.name_prefix}-documents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "document_id"

  attribute {
    name = "document_id"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-documents"
  })
}

resource "aws_sns_topic" "document_notifications" {
  name = "${local.name_prefix}-document-notifications"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-document-notifications"
  })
}

resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${local.name_prefix}-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.documents.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.document_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.uploads.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "create_document_record" {
  function_name = "${local.name_prefix}-create-document"

  filename         = "${path.module}/lambda/create_document_record.zip"
  handler          = "create_document_record.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64sha256("${path.module}/lambda/create_document_record.zip")

  environment {
    variables = {
      TABLE_NAME    = aws_dynamodb_table.documents.name
      UPLOAD_BUCKET = aws_s3_bucket.uploads.bucket
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_function" "process_uploaded_document" {
  function_name = "${local.name_prefix}-process-document"

  filename         = "${path.module}/lambda/process_uploaded_document.zip"
  handler          = "process_uploaded_document.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64sha256("${path.module}/lambda/process_uploaded_document.zip")

  environment {
    variables = {
      TABLE_NAME    = aws_dynamodb_table.documents.name
      SNS_TOPIC_ARN = aws_sns_topic.document_notifications.arn
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "allow_s3_invoke_process_lambda" {
  statement_id  = "AllowS3InvokeProcessLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_uploaded_document.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

resource "aws_s3_bucket_notification" "uploads_notification" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_uploaded_document.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke_process_lambda
  ]
}
resource "aws_apigatewayv2_api" "document_api" {
  name          = "${local.name_prefix}-document-api"
  protocol_type = "HTTP"

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "create_document_integration" {
  api_id                 = aws_apigatewayv2_api.document_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create_document_record.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_document_route" {
  api_id    = aws_apigatewayv2_api.document_api.id
  route_key = "POST /documents"
  target    = "integrations/${aws_apigatewayv2_integration.create_document_integration.id}"
}

resource "aws_apigatewayv2_stage" "document_api_stage" {
  api_id      = aws_apigatewayv2_api.document_api.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

resource "aws_lambda_permission" "allow_apigw_invoke_create_document" {
  statement_id  = "AllowAPIGatewayInvokeCreateDocument"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_document_record.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.document_api.execution_arn}/*/*"
}
resource "aws_lambda_function" "get_document_status" {
  function_name = "${local.name_prefix}-get-document-status"

  filename         = "${path.module}/lambda/get_document_status.zip"
  handler          = "get_document_status.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64sha256("${path.module}/lambda/get_document_status.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.documents.name
    }
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "get_document_status_integration" {
  api_id                 = aws_apigatewayv2_api.document_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_document_status.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_document_status_route" {
  api_id    = aws_apigatewayv2_api.document_api.id
  route_key = "GET /documents/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_document_status_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_invoke_get_document_status" {
  statement_id  = "AllowAPIGatewayInvokeGetDocumentStatus"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_document_status.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.document_api.execution_arn}/*/*"
}