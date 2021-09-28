locals {
  source_sha = sha1(join("", [for f in fileset(path.module, "batch_lambda/{index.js,package.json,package-lock.json}"): sha1(file(f))]))
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy" "basic_lambda_execution" {
  name = "AWSLambdaBasicExecutionRole"
}

resource "null_resource" "batch_lambda_node_modules" {
  triggers = {
    source = local.source_sha
  }

  provisioner "local-exec" {
    command     = "npm install --no-bin-links"
    working_dir = "${path.module}/batch_lambda"
  }
}

data "archive_file" "batch_lambda" {
  depends_on    = [null_resource.batch_lambda_node_modules]
  type          = "zip"
  source_dir    = "${path.module}/batch_lambda"
  output_path   = "${path.module}/package/${local.source_sha}.zip"
}

data "aws_iam_policy_document" "batch_lambda_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.active_job_queue["batch_ingest"].arn]
  }
}

resource "aws_iam_policy" "batch_lambda_policy" {
  name    = "stack-avr-batch-ingest"
  policy  = data.aws_iam_policy_document.batch_lambda_policy.json
  tags    = local.tags
}

resource "aws_iam_role" "batch_lambda_role" {
  name                  = "stack-avr-batch-ingest"
  assume_role_policy    = data.aws_iam_policy_document.lambda_assume_role.json
  tags                  = local.tags
}

resource "aws_iam_role_policy_attachment" "batch_lambda_role_policy" {
  role          = aws_iam_role.batch_lambda_role.name
  policy_arn    = aws_iam_policy.batch_lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "basic_lambda_execution_policy" {
  role          = aws_iam_role.batch_lambda_role.name
  policy_arn    = data.aws_iam_policy.basic_lambda_execution.arn
}

resource "aws_lambda_function" "batch_lambda" {
  filename      = data.archive_file.batch_lambda.output_path
  function_name = "stack-avr-batch-ingest"
  role          = aws_iam_role.batch_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  memory_size   = 128
  timeout       = 5
  publish       = true
  tags          = local.tags

  environment {
    variables = {
      JobClassName    = "BatchIngestJob"
      Secret          = random_id.secret_key_base.hex
      QueueName       = aws_sqs_queue.active_job_queue["batch_ingest"].name
      QueueUrl        = aws_sqs_queue.active_job_queue["batch_ingest"].url
    }
  }
}

resource "aws_lambda_permission" "allow_bucket_notification" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.avr_masterfiles.arn
}

resource "aws_s3_bucket_notification" "batch_lambda_notification" {
  depends_on    = [aws_lambda_permission.allow_bucket_notification]
  bucket        = aws_s3_bucket.avr_masterfiles.id

  dynamic "lambda_function" {
    for_each = toset([".xls", ".xlsx"])
    iterator = extension

    content {
      lambda_function_arn   = aws_lambda_function.batch_lambda.arn
      events                = ["s3:ObjectCreated:*"]
      filter_prefix         = "dropbox/"
      filter_suffix         = extension.key
    }
  }
}
