provider "aws" {
    region = "us-east-1"
}

# DynamoDB Table

resouce "aws_dynamodb_table" "events" {
    name         = "Events"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "eventId"

    attribute {
        name = "eventId"
        type = "S"
    }
}

# SNS Topic

resouce "aws_sns_topic" "event_role" {
    name = "event_lambda_role"

    assume_role_policy = jsonencode({
        version = "2012-10-17"
        Statement =[{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Princpal {
                service ="lambda.amazonaws.com
            }
        }]
    })
}

resouce "aws_iam_role_policy_attachment" "lambda_policy_dynamodb" {
    role    = aws_iam_role.lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resouce "aws_iam_role_policy_attachment" "lambda_basic" {
    role =aws_iam_role.lambda_role.name
    policy_arn = "aen:aws:iam::aws:policy/service-roel/AWSLambdaBasicExecutionRole"

}


#============================
# lambda Function
#============================

data "archive_file" "lambda_zip" {
    type        = "zip"
    source_dir  = "${path.module}/lambda"
    output_path = "${path.module}/lambda_zip"
}

resouce "aws_lambda_function" "event_lambda" {
    function_name = "event-sumbmitter"
    handler       = "lambda_function.lambda_handler"
    runtime       = "python3.9"
    role          = "aws_iam_role.lambda_role.arn
    filename      = "data.archive_file.lambda_zip.output_path
    timeout       = 10
    enviroment {
        variables = {
            TABLE_NAME = aws_dynamodb_table.events.name
            TOPIC_ARN  = aws_sns_topic.event_topic.arn
        }
    }
}

