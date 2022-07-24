provider "aws" {
  region = "ap-southeast-2"
}

locals {
  default_tags = {
    ManagedBy = "Terraform"
  }
}


# cloudwatch log group for the lambda function
resource "aws_cloudwatch_log_group" "lambda_log" {
  name              = "/aws/lambda/${aws_lambda_function.my_php_lambda.function_name}"
  retention_in_days = 30 #  always retained and never expire

  tags = local.default_tags
}

# IAM - lambda function basic exec role
resource "aws_iam_role" "container_lambda_exec_role" {
  name        = "container_lambda_exec_role"
  description = "IAM role for container lambda exec role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "container_lambda_exec_role" {
  role       = aws_iam_role.container_lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



# lambda function
data "aws_ecr_image" "service_image" {
  repository_name = "php-lambda-function"
  image_tag       = "latest"
}

data "aws_ecr_repository" "service" {
  name = "php-lambda-function"
}


resource "aws_lambda_function" "my_php_lambda" {
  function_name = "my-hello-world"

  architectures = ["arm64"]
  package_type  = "Image"
  image_uri     = "${data.aws_ecr_repository.service.repository_url}@${data.aws_ecr_image.service_image.image_digest}"
  role          = aws_iam_role.container_lambda_exec_role.arn

  tags = local.default_tags
}

#output "repository" {
#  value = data.aws_ecr_repository.service.repository_url
#}
#
#output "image_digest" {
#  value = data.aws_ecr_image.service_image.image_digest
#}


# API Gateway
resource "aws_api_gateway_rest_api" "lambda" {
  name = "my-php-function-api"

  # Regional
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.default_tags
}

#resource "aws_api_gateway_resource" "proxy" {
#
#  parent_id   = aws_api_gateway_rest_api.lambda.root_resource_id
#  rest_api_id = aws_api_gateway_rest_api.lambda.id
#  path_part = "{}"
#}


# request mapping
resource "aws_api_gateway_method" "hello" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_rest_api.lambda.root_resource_id
  rest_api_id   = aws_api_gateway_rest_api.lambda.id
}

resource "aws_api_gateway_integration" "hello_integration" {

  http_method             = aws_api_gateway_method.hello.http_method
  resource_id             = aws_api_gateway_rest_api.lambda.root_resource_id
  rest_api_id             = aws_api_gateway_rest_api.lambda.id
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_php_lambda.invoke_arn
  integration_http_method = "POST"
}


# deployment

resource "aws_api_gateway_deployment" "hello" {
  rest_api_id = aws_api_gateway_rest_api.lambda.id


  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.lambda.root_resource_id,
      aws_api_gateway_method.hello.id,
      aws_api_gateway_integration.hello_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "test" {
  deployment_id = aws_api_gateway_deployment.hello.id
  rest_api_id   = aws_api_gateway_rest_api.lambda.id
  stage_name    = "test"
}


# API permission

resource "aws_lambda_permission" "allow_api_gateway" {

  function_name = aws_lambda_function.my_php_lambda.function_name
  statement_id = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lambda.execution_arn}/*/*/*"

  depends_on = [
    aws_api_gateway_rest_api.lambda
  ]
}

