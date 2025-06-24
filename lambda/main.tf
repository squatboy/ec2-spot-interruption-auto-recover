variable "data_volume_tag" { type = string }
variable "region" { type = string }

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "spot-backup-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "spot-backup-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot", "ec2:CreateTags",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:SendCommand"]
        Resource = "*"
      },
      { Effect = "Allow", Action = [
        "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"
      ], Resource = "*" }
    ]
  })
}

data "archive_file" "zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/handler.zip"
}

resource "aws_lambda_function" "backup" {
  function_name = "spot-interrupt-backup"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.zip.output_path

  environment {
    variables = {
      VOLUME_TAG   = var.data_volume_tag
      SSM_DOCUMENT = "AWS-RunShellScript"
    }
  }
}

# EventBridge Rule
resource "aws_cloudwatch_event_rule" "spot_interrupt" {
  name        = "spot-interruption-rule"
  description = "Spot 인스턴스 중단 경고 감지"
  event_pattern = jsonencode({
    source        = ["aws.ec2"],
    "detail-type" = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "to_lambda" {
  rule      = aws_cloudwatch_event_rule.spot_interrupt.name
  arn       = aws_lambda_function.backup.arn
  target_id = "invoke-lambda"
}

resource "aws_lambda_permission" "allow_event" {
  statement_id  = "AllowExecFromEvent"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.spot_interrupt.arn
}
