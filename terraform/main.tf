provider "aws" {
  region = "ap-south-1"
}

resource "aws_dynamodb_table" "url_shortener" {
  name         = "URLShortener"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_id"

  attribute {
    name = "short_id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}

resource "aws_lambda_function" "shorten_url" {
  filename         = "shorten.zip"
  function_name    = "shorten_url"
  role             = aws_iam_role.lambda_role.arn
  handler          = "shorten.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("shorten.zip")
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.url_shortener.name
    }
  }
}

resource "aws_lambda_function" "redirect_url" {
  filename         = "redirect.zip"
  function_name    = "redirect_url"
  role             = aws_iam_role.lambda_role.arn
  handler          = "redirect.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = filebase64sha256("redirect.zip")
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.url_shortener.name
    }
  }
}

resource "aws_api_gateway_rest_api" "url_shortener_api" {
  name        = "URLShortenerAPI"
  description = "API for URL Shortener Service"
}

resource "aws_api_gateway_resource" "shorten_resource" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  parent_id   = aws_api_gateway_rest_api.url_shortener_api.root_resource_id
  path_part   = "shorten"
}

resource "aws_api_gateway_method" "shorten_method" {
  rest_api_id   = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id   = aws_api_gateway_resource.shorten_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "shorten_integration" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.shorten_resource.id
  http_method = aws_api_gateway_method.shorten_method.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.shorten_url.invoke_arn
}

resource "aws_api_gateway_resource" "redirect_resource" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  parent_id   = aws_api_gateway_rest_api.url_shortener_api.root_resource_id
  path_part   = "{short_id}"
}

resource "aws_api_gateway_method" "redirect_method" {
  rest_api_id   = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id   = aws_api_gateway_resource.redirect_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "redirect_integration" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.redirect_resource.id
  http_method = aws_api_gateway_method.redirect_method.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.redirect_url.invoke_arn
}

output "api_url" {
  value = aws_api_gateway_rest_api.url_shortener_api.execution_arn
}
