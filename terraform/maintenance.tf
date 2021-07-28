resource "aws_cloudwatch_event_rule" "database_maintenance" {
  name                  = "${var.app_name}-db-maintenance"
  description           = "Clean and vacuum AVR searches and sessions tables"
  schedule_expression   = "cron(0 8 ? * * *)"
  }

resource "aws_cloudwatch_event_target" "database_maintenance" {
  target_id = "${var.app_name}-db-maintenance-lambda"
  rule = aws_cloudwatch_event_rule.database_maintenance.name
  arn = module.data_services.outputs.postgres.maintenance_lambda

  input = jsonencode({
    connection = {
      host = module.data_services.outputs.postgres.address
      port = module.data_services.outputs.postgres.port
      user = var.app_name
      password = module.db_schema.password
      database = var.app_name
    }
    tables = [
      "sessions",
      "searches"
    ]
    max_age = "1 DAY"
  })
}

data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "restart_container" {
  statement {
    effect    = "Allow"
    actions   = ["ecs:UpdateService"]
    resources = ["arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.id}:service/${aws_ecs_cluster.avr.name}/${aws_ecs_service.avr_webapp.name}"]
  }
}

resource "aws_iam_role" "restart_webapp" {
  name                  = "${var.app_name}-restart-container"
  assume_role_policy    = data.aws_iam_policy_document.scheduler_assume_role.json

  inline_policy {
    name    = "${var.app_name}-restart-container"
    policy  = data.aws_iam_policy_document.restart_container.json
  }
}

resource "aws_scheduler_schedule" "restart_webapp" {
  name       = "restart-${var.app_name}-webapp"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression             = "cron(0 8/12 * * ? *)"
  schedule_expression_timezone    = "America/Chicago"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.restart_webapp.arn

    input = jsonencode({
      Cluster               = aws_ecs_cluster.avr.name
      Service               = aws_ecs_service.avr_webapp.name
      ForceNewDeployment    = true
    })
  }
}