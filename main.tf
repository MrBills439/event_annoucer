provider "aws" {
    region = "us-east-1"
}

# DynamoDB Table

resource "aws_dynamodb_table" "events" {
    name         = "Events"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "eventId"

    attribute {
        name = "eventId"
        type = "S"
    }
}


# =============================
# SNS Topic
# =============================
resource "aws_sns_topic" "event_topic" {
  name = "event-topic"
}

# =============================
# IAM Role for Lambda
# =============================
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach policies
resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}












#============================
# lambda Function
#============================

data "archive_file" "lambda_zip" {
    type        = "zip"
    source_dir  = "${path.module}/lambda"
    output_path = "${path.module}/lambda_zip"
}

resource "aws_lambda_function" "event_lambda" {
  function_name = "eventLambda"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda_zip.output_path
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.event_table.name
      TOPIC_ARN  = aws_sns_topic.event_topic.arn
    }
  }
}


#======================
# API Gateway
#======================

resource "aws_apigatewayv2_api" "api" {
    name            = "event-api"
    protocol_type   = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.event_lambda.invoke_arn

}

resource "aws_apigatewayv2_route" "post_event" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /event"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}



# =============================
#  S3 Bucket for Frontend
# =============================
resource "aws_s3_bucket" "frontend" {
  bucket = "event-announcer-frontend-${random_integer.rand.result}"
  acl    = "public-read"

  website {
    index_document = "index.html"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend.bucket
  index_document {
    suffix = "index.html"
  }
}

resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
  acl          = "public-read"
}

# =============================
#  Outputs
# =============================
output "api_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

output "frontend_url" {
  value = aws_s3_bucket.frontend.website_endpoint
}

