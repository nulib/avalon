resource "aws_ecs_cluster" "avr" {
  name = var.app_name
  tags = local.tags
}

data "aws_acm_certificate" "avr_cert" {
  domain = local.avr_certificate_domain
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "avr_role_permissions" {
  statement {
    sid    = "lambda"
    effect = "Allow"
    actions = [
      "lambda:GetFunction",
      "lambda:InvokeFunction"
    ]
    resources = ["*"]
  }
  
  statement {
    sid    = "sns"
    effect = "Allow"
    actions = [
      "sns:CreateTopic",
      "sns:GetSubscriptionAttributes",
      "sns:ListSubscriptions",
      "sns:ListTopics",
      "sns:Publish",
      "sns:SetSubscriptionAttributes",
      "sns:Subscribe",
      "sns:Unsubscribe"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "sqs"
    effect = "Allow"
    actions = [
      "sqs:CreateQueue",
      "sqs:DeleteMessage",
      "sqs:DeleteMessageBatch",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:SendMessageBatch",
      "sqs:SetQueueAttributes"
    ]
    resources = ["arn:aws:sqs:${local.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    sid    = "configuration"
    effect = "Allow"
    actions = [
      "ssm:GetParameter*"
    ]
    resources = ["arn:aws:ssm:${local.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.app_name}*"]
  }

  statement {
    sid    = "transcoding"
    effect = "Allow"
    actions = [
      "events:PutRule",
      "events:PutTargets",
      "logs:*",
      "mediaconvert:CancelJob",
      "mediaconvert:CreateJob",
      "mediaconvert:DescribeEndpoints",
      "mediaconvert:GetJob",
      "mediaconvert:GetQueue"
    ]
    resources = ["*"]
  }

  statement {
    sid = "email"
    effect = "Allow"
    actions = [
      "ses:Send*"
    ]
    resources = ["*"]
  }
}

resource "aws_security_group" "avr_load_balancer" {
  name          = "${var.app_name}-lb"
  description   = "avr Load Balancer Security Group"
  vpc_id        = module.core.outputs.vpc.id
  tags          = local.tags

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description   = "HTTP in"
    from_port     = 80
    to_port       = 80
    protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
  }

  ingress {
    description   = "HTTPS in"
    from_port     = 443
    to_port       = 443
    protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy" "ecs_exec_command" {
  name = "allow-ecs-exec"
}

resource "aws_iam_role" "avr_role" {
  name               = "${var.app_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  tags               = local.tags
}

resource "aws_iam_policy" "avr_role_policy" {
  name   = "${var.app_name}-policy"
  policy = data.aws_iam_policy_document.avr_role_permissions.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "avr_role_policy" {
  role       = aws_iam_role.avr_role.id
  policy_arn = aws_iam_policy.avr_role_policy.arn
}

resource "aws_iam_policy" "this_bucket_policy" {
  name   = "avr-bucket-access"
  policy = data.aws_iam_policy_document.this_bucket_access.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "bucket_role_access" {
  role       = aws_iam_role.avr_role.name
  policy_arn = aws_iam_policy.this_bucket_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_exec_command" {
  role       = aws_iam_role.avr_role.id
  policy_arn = data.aws_iam_policy.ecs_exec_command.arn
}

resource "aws_iam_role_policy_attachment" "avr_transcode_passrole" {
  role       = aws_iam_role.avr_role.name
  policy_arn = aws_iam_policy.allow_transcode.arn
}

resource "aws_cloudwatch_log_group" "avr_logs" {
  name = "/ecs/${var.app_name}"
  tags = local.tags
}
resource "aws_lb_target_group" "avr_target" {
  port                    = 3000
  deregistration_delay    = 30
  target_type             = "ip"
  protocol                = "HTTP"
  vpc_id                  = module.core.outputs.vpc.id
  tags                    = local.tags

  stickiness {
    enabled = false
    type    = "lb_cookie"
  }
}

resource "aws_lb" "avr_load_balancer" {
  name               = "${var.app_name}-lb"
  internal           = false
  load_balancer_type = "application"

  subnets         = module.core.outputs.vpc.public_subnets.ids
  security_groups = [aws_security_group.avr_load_balancer.id]
  tags    = local.tags
}

resource "aws_lb_listener" "avr_lb_listener_http" {
  load_balancer_arn = aws_lb.avr_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.tags
}

resource "aws_lb_listener" "avr_lb_listener_https" {
  load_balancer_arn = aws_lb.avr_load_balancer.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.avr_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.avr_target.arn
  }

  tags = local.tags
}

resource "random_id" "secret_key_base" {
  byte_length = 32
}
