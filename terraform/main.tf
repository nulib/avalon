terraform {
  backend "s3" {
    key    = "avr.tfstate"
  }
}

provider "aws" { }

data "aws_region" "current" { }

locals {
  aws_region            = data.aws_region.current.name
  namespace             = module.core.outputs.stack.namespace
  tags                  = merge(module.core.outputs.stack.tags, var.tags)
  zookeeper_endpoint    = "${element(module.solrcloud.outputs.zookeeper.servers, 0)}/configs"
}

module "core" {
  source = "git::https://github.com/nulib/infrastructure.git//modules/remote_state"
  component = "core"
}

module "data_services" {
  source = "git::https://github.com/nulib/infrastructure.git//modules/remote_state"
  component = "data_services"
}

module "fcrepo" {
  source = "git::https://github.com/nulib/infrastructure.git//modules/remote_state"
  component = "fcrepo"
}

module "solrcloud" {
  source = "git::https://github.com/nulib/infrastructure.git//modules/remote_state"
  component = "solrcloud"
}

data "aws_acm_certificate" "streaming_cert" {
  domain = local.streaming_certificate_domain
}

resource "aws_s3_bucket" "avr_masterfiles" {
  bucket = "${local.namespace}-avr-masterfiles"
  tags   = local.tags


  lifecycle {
    ignore_changes = [bucket]
  }  
}

resource "aws_s3_bucket_acl" "avr_masterfiles" {
  bucket = aws_s3_bucket.avr_masterfiles.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "avr_masterfiles" {
  bucket = aws_s3_bucket.avr_masterfiles.id
  rule {
    bucket_key_enabled = false
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "avr_masterfiles" {
  bucket = aws_s3_bucket.avr_masterfiles.id
  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]    
  }
}

resource "aws_s3_bucket" "avr_streaming" {
  bucket = "${local.namespace}-avr-derivatives"
  tags = local.tags

  lifecycle {
    ignore_changes = [bucket]
  }  
}

resource "aws_s3_bucket_acl" "avr_streaming" {
  bucket = aws_s3_bucket.avr_streaming.id
  acl    = "private"
}

resource "aws_s3_bucket_cors_configuration" "avr_streaming" {
  bucket = aws_s3_bucket.avr_streaming.id
  cors_rule {
    allowed_origins = ["*.northwestern.edu"]
    allowed_methods = ["GET"]
    max_age_seconds = "3000"
    allowed_headers = ["Authorization", "Access-Control-Allow-Origin"]
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "avr_streaming" {
  bucket = aws_s3_bucket.avr_streaming.id
  rule {
    bucket_key_enabled = false
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "avr_preservation" {
  bucket = "${local.namespace}-avr-preservation"
  tags = local.tags

  lifecycle {
    ignore_changes = [bucket]
  }  
}

resource "aws_s3_bucket_acl" "avr_preservation" {
  bucket = aws_s3_bucket.avr_preservation.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "avr_preservation" {
  bucket = aws_s3_bucket.avr_preservation.id
  rule {
    bucket_key_enabled = false
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "avr_preservation" {
  bucket = aws_s3_bucket.avr_preservation.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "avr_preservation_production" {
  bucket = aws_s3_bucket.avr_preservation.id
  name   = "intelligent-archive"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

# Production Preservation Bucket
resource "aws_s3_bucket_lifecycle_configuration" "avr_preservation_production" {
  bucket = aws_s3_bucket.avr_preservation.id

  rule {
    id = "intelligent-tiering"

    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "retain-on-delete"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
    expiration {
      expired_object_delete_marker = true
    }
  }
}

resource "aws_s3_bucket" "avr_active_storage" {
  bucket = "${local.namespace}-avr-active-storage"
  tags   = local.tags

  lifecycle {
    ignore_changes = [bucket]
  }  
}

resource "aws_s3_bucket_acl" "avr_active_storage" {
  bucket = aws_s3_bucket.avr_active_storage.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "avr_active_storage" {
  bucket = aws_s3_bucket.avr_active_storage.id
  rule {
    bucket_key_enabled = false
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "this_bucket_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:ListAllMyBuckets"
    ]
    resources = ["arn:aws:s3:::*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy"
    ]

    resources = [
      aws_s3_bucket.avr_active_storage.arn,
      aws_s3_bucket.avr_masterfiles.arn,
      aws_s3_bucket.avr_streaming.arn,
      aws_s3_bucket.avr_preservation.arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = [
      "${aws_s3_bucket.avr_active_storage.arn}/*",
      "${aws_s3_bucket.avr_masterfiles.arn}/*",
      "${aws_s3_bucket.avr_streaming.arn}/*",
      "${aws_s3_bucket.avr_preservation.arn}/*"    ]
  }
}

resource "aws_security_group" "avr" {
  name        = var.app_name
  description = "The AVR Application"
  vpc_id      = module.core.outputs.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group_rule" "allow_alb_access" {
  type              = "ingress"
  from_port         = "3000"
  to_port           = "3000"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.avr.id
}

resource "aws_route53_record" "app_hostname" {
  zone_id = module.core.outputs.vpc.public_dns_zone.id
  name    = var.app_name
  type    = "A"

  alias {
    name                   = aws_lb.avr_load_balancer.dns_name
    zone_id                = aws_lb.avr_load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_iam_role" "transcode_role" {
  name = "${var.app_name}-transcode-role"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${var.app_name}-transcode-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:Get*", "s3:List*"]
          Resource = [
            "${aws_s3_bucket.avr_masterfiles.arn}/*",
            "${aws_s3_bucket.avr_preservation.arn}/*"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["s3:Put*"]
          Resource = ["${aws_s3_bucket.avr_streaming.arn}/*"]
        }
      ]
    })
  }
}

data "aws_iam_policy_document" "pass_transcode_role" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.transcode_role.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "events:ListRules",
      "events:PutRule",
      "events:PutTargets",
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:GetQueryResults",
      "logs:StartQuery",
      "mediaconvert:CancelJob",
      "mediaconvert:CreateJob",
      "mediaconvert:DescribeEndpoints",
      "mediaconvert:GetJob",
      "mediaconvert:GetQueue"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "allow_transcode" {
  name   = "${var.app_name}-mediaconvert-access"
  policy = data.aws_iam_policy_document.pass_transcode_role.json
  tags   = local.tags
}

resource "aws_media_convert_queue" "transcode_queue" {
  name   = var.app_name
  status = "ACTIVE"
  tags   = local.tags
}

resource "aws_cloudwatch_log_group" "mediaconvert_state_change_log" {
  name                = "/aws/events/active-encode/mediaconvert/${aws_media_convert_queue.transcode_queue.name}"
  retention_in_days   = 7
  tags                = local.tags
}

resource "aws_cloudwatch_event_rule" "mediaconvert_state_change" {
  name        = "${var.app_name}-mediaconvert-state-change"
  description = "Send MediaConvert state changes to Meadow"
  tags        = local.tags

  event_pattern = jsonencode({
    source        = ["aws.mediaconvert"]
    "detail-type" = ["MediaConvert Job State Change"]
    detail = {
      queue  = [aws_media_convert_queue.transcode_queue.arn]
    }
  })
}

resource "aws_cloudwatch_event_target" "mediaconvert_state_change_cloudwatch_log" {
  rule      = aws_cloudwatch_event_rule.mediaconvert_state_change.name
  target_id = "SendToCloudwatchLogs"
  arn       = aws_cloudwatch_log_group.mediaconvert_state_change_log.arn
}

resource "aws_cloudfront_origin_access_identity" "avr_streaming_access_identity" {
  comment = var.app_name
}

data "aws_iam_policy_document" "avr_streaming_bucket_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.avr_streaming.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.avr_streaming_access_identity.iam_arn]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.avr_streaming.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.avr_streaming_access_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront_streaming_access" {
  bucket = aws_s3_bucket.avr_streaming.id
  policy = data.aws_iam_policy_document.avr_streaming_bucket_policy.json
}

resource "aws_cloudfront_public_key" "avr_stream_public_key" {
  name        = "${var.app_name}-signing-key"
  encoded_key = var.cloudfront_public_key
}

resource "aws_cloudfront_key_group" "avr_stream_signing_key_group" {
  items = [aws_cloudfront_public_key.avr_stream_public_key.id]
  name  = "${var.app_name}-signing-keys"
}

resource "aws_cloudfront_function" "avr_streaming_cors" {
  name = "${var.app_name}-cors-streaming-headers"
  runtime = "cloudfront-js-1.0"
  publish = true
  code = file("${path.module}/js/cors_streaming_headers.js")
}

resource "aws_cloudfront_distribution" "avr_streaming" {
  enabled          = true
  is_ipv6_enabled  = true
  retain_on_delete = true
  aliases          = compact(concat([var.streaming_hostname], ["httpstream.${module.core.outputs.vpc.public_dns_zone.name}"]))
  price_class      = "PriceClass_100"
  tags             = local.tags

  origin {
    domain_name = aws_s3_bucket.avr_streaming.bucket_domain_name
    origin_id   = "${local.namespace}-${var.app_name}-origin-hls"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.avr_streaming_access_identity.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${local.namespace}-${var.app_name}-origin-hls"
    viewer_protocol_policy = "allow-all"

    forwarded_values {
      cookies {
        forward = "none"
      }

      query_string = false
      headers      = ["Origin"]
    }

    trusted_key_groups = [aws_cloudfront_key_group.avr_stream_signing_key_group.id]

    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.avr_streaming_cors.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = join("", data.aws_acm_certificate.streaming_cert.*.arn)
    ssl_support_method             = "sni-only"
  }
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

resource "aws_route53_record" "avr_streaming_cloudfront" {
  zone_id = module.core.outputs.vpc.public_dns_zone.id
  name    = "httpstream"
  type    = "CNAME"
  ttl     = "900"
  records = [aws_cloudfront_distribution.avr_streaming.domain_name]
}
