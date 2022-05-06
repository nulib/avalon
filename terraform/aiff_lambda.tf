locals {
  aiff_source_sha = sha1(join("", [for f in fileset(path.module, "aiff_lambda/{index.js,package.json,package-lock.json}"): sha1(file(f))]))
}

resource "null_resource" "aiff_lambda_node_modules" {
  triggers = {
    source = local.aiff_source_sha
  }

  provisioner "local-exec" {
    command     = "npm install --production --no-bin-links && npm prune --production"
    working_dir = "${path.module}/aiff_lambda"
  }
}

data "archive_file" "aiff_lambda" {
  depends_on    = [null_resource.aiff_lambda_node_modules]
  type          = "zip"
  source_dir    = "${path.module}/aiff_lambda"
  output_path   = "${path.module}/package/${local.aiff_source_sha}.zip"
}

resource "aws_iam_policy" "aiff_lambda_policy" {
  name    = "stack-avr-aiff-to-wav"
  policy  = data.aws_iam_policy_document.this_bucket_access.json
  tags    = local.tags
}

resource "aws_iam_role" "aiff_lambda_role" {
  name                  = "stack-avr-aiff-to-wav"
  assume_role_policy    = data.aws_iam_policy_document.lambda_assume_role.json
  tags                  = local.tags
}

resource "aws_iam_role_policy_attachment" "aiff_lambda_role_policy" {
  role          = aws_iam_role.aiff_lambda_role.name
  policy_arn    = aws_iam_policy.aiff_lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "aiff_lambda_execution_policy" {
  role          = aws_iam_role.aiff_lambda_role.name
  policy_arn    = data.aws_iam_policy.basic_lambda_execution.arn
}

data "aws_lambda_layer_version" "ffmpeg" {
  layer_name = "ffmpeg"
}

resource "aws_lambda_function" "aiff_lambda" {
  filename      = data.archive_file.aiff_lambda.output_path
  function_name = "stack-avr-aiff-to-wav"
  role          = aws_iam_role.aiff_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  memory_size   = 256
  timeout       = 300
  layers        = [data.aws_lambda_layer_version.ffmpeg.arn]
  publish       = true
  tags          = local.tags
}
