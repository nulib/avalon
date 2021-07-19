terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

data "aws_acm_certificate" "wildcard_cert" {
  domain = "*.${trimsuffix(data.aws_route53_zone.stack_public_zone.name, ".")}"
}

locals {
  common_tags = merge(
    var.tags,
    {
      Terraform = "true",
      Environment = local.stack_namespace,
      Project = "AVR"
    }
  )
  domain_host = "${var.app_name}.${data.aws_route53_zone.stack_public_zone.name}"
}

resource "aws_s3_bucket" "avr_masterfiles" {
  bucket = "${local.stack_namespace}-avr-masterfiles"
  acl    = "private"
  tags   = "${local.common_tags}"


  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
  }

  lifecycle {
    ignore_changes = [bucket, tags]
  }  
}

resource "aws_s3_bucket" "avr_streaming" {
  bucket = "${local.stack_namespace}-avr-derivatives"
  acl  = "private"
  tags = "${local.common_tags}"

  cors_rule {
    allowed_origins = ["*.northwestern.edu"]
    allowed_methods = ["GET"]
    max_age_seconds = "3000"
    allowed_headers = ["Authorization", "Access-Control-Allow-Origin"]
  }

  lifecycle {
    ignore_changes = [bucket, tags]
  }  
}

resource "aws_s3_bucket" "avr_preservation" {
  bucket = "${local.stack_namespace}-avr-preservation"
  acl  = "private"
  tags = "${local.common_tags}"

  lifecycle {
    ignore_changes = [bucket, tags]
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
      "${aws_s3_bucket.avr_masterfiles.arn}/*",
      "${aws_s3_bucket.avr_streaming.arn}/*",
      "${aws_s3_bucket.avr_preservation.arn}/*"    ]
  }
}

resource "aws_security_group" "avr" {
  name        = var.app_name
  description = "The AVR Application"
  vpc_id      = data.aws_vpc.stack_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
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
  zone_id = data.aws_route53_zone.stack_public_zone.zone_id
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
          Resource = ["${aws_s3_bucket.avr_preservation.arn}/*"]
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
      "mediaconvert:CreateJob",
      "mediaconvert:DescribeEndpoints"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "allow_transcode" {
  name   = "${var.app_name}-mediaconvert-access"
  policy = data.aws_iam_policy_document.pass_transcode_role.json
}

resource "aws_media_convert_queue" "transcode_queue" {
  name   = var.app_name
  status = "ACTIVE"
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

resource "aws_cloudfront_distribution" "avr_streaming" {
  enabled          = true
  is_ipv6_enabled  = true
  retain_on_delete = true
  aliases          = ["httpstream.${data.aws_route53_zone.stack_public_zone.name}"]
  price_class      = "PriceClass_100"

  origin {
    domain_name = aws_s3_bucket.avr_streaming.bucket_domain_name
    origin_id   = "${local.stack_namespace}-${var.app_name}-origin-hls"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.avr_streaming_access_identity.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${local.stack_namespace}-${var.app_name}-origin-hls"
    viewer_protocol_policy = "allow-all"

    forwarded_values {
      cookies {
        forward = "none"
      }

      query_string = false
      headers      = ["Origin"]
    }

    trusted_key_groups = [aws_cloudfront_key_group.avr_stream_signing_key_group.id]
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = join("", data.aws_acm_certificate.wildcard_cert.*.arn)
    ssl_support_method             = "sni-only"
  }
}

resource "aws_route53_record" "avr_streaming_cloudfront" {
  zone_id = data.aws_route53_zone.stack_public_zone.zone_id
  name    = "httpstream"
  type    = "CNAME"
  ttl     = "900"
  records = [aws_cloudfront_distribution.avr_streaming.domain_name]
}
