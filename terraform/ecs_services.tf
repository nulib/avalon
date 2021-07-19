locals {
  avr_urls = [for hostname in concat([aws_route53_record.app_hostname.fqdn], var.additional_hostnames) : "//${hostname}"]

  container_config = {
    app_name                  = var.app_name
    aws_region                = var.aws_region
    database_url              = "postgresql://${var.app_name}:${random_string.db_password.result}@${data.aws_db_instance.stack_db.endpoint}/${var.app_name}"
    docker_tag                = terraform.workspace
    fedora_base_path          = "/${var.app_name}"
    fedora_url                = local.stack_fedora_url
    honeybadger_api_key       = var.honeybadger_api_key
    honeybadger_environment   = var.environment == "s" ? "staging" : "production"
    host_name                 = aws_route53_record.app_hostname.fqdn
    log_group                 = aws_cloudwatch_log_group.avr_logs.name
    lti_auth_key              = var.lti_auth_key
    lti_auth_secret           = var.lti_auth_secret
    mediaconvert_queue        = aws_media_convert_queue.transcode_queue.arn
    mediaconvert_role         = aws_iam_role.transcode_role.arn
    preservation_bucket       = aws_s3_bucket.avr_preservation.bucket
    redis_host                = data.aws_elasticache_cluster.stack_redis.cache_nodes.0.address
    redis_port                = data.aws_elasticache_cluster.stack_redis.cache_nodes.0.port
    region                    = var.aws_region
    secret_key_base           = random_string.secret_key_base.result
    solr_url                  = "${local.stack_solr_url}/avr"
    streaming_url             = "https://${aws_route53_record.avr_streaming_cloudfront.fqdn}/"
    zookeeper_endpoint        = local.stack_zookeeper_endpoint
  }
}

resource "random_string" "db_password" {
  length  = 16
  upper   = true
  lower   = true
  number  = true
  special = false
}

module "avr_task_webapp" {
  source           = "./modules/avr_task"
  container_config = local.container_config
  cpu              = 2048
  memory           = 4096
  container_role   = "webapp"
  role_arn         = aws_iam_role.avr_role.arn
  app_name         = var.app_name
  tags             = var.tags
}

resource "aws_ecs_service" "avr_webapp" {
  name                              = "${var.app_name}-webapp"
  cluster                           = aws_ecs_cluster.avr.id
  task_definition                   = module.avr_task_webapp.task_definition.arn
  desired_count                     = 1
  enable_execute_command            = true
  health_check_grace_period_seconds = 600
  launch_type                       = "FARGATE"
  depends_on                        = [aws_lb.avr_load_balancer]
  platform_version                  = "1.4.0"

  load_balancer {
    target_group_arn = aws_lb_target_group.avr_target.arn
    container_name   = "avr"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets          = data.aws_subnet_ids.stack_private_subnets.ids
    security_groups  = [
      aws_security_group.avr.id, 
      data.aws_security_group.stack_db_client_security_group.id
    ]
    assign_public_ip = false
  }

  tags = var.tags
}

module "avr_task_worker" {
  source           = "./modules/avr_task"
  container_config = local.container_config
  cpu              = 2048
  memory           = 4096
  container_role   = "worker"
  role_arn         = aws_iam_role.avr_role.arn
  app_name         = var.app_name
  tags             = var.tags
}

resource "aws_ecs_service" "avr_worker" {
  name                              = "${var.app_name}-worker"
  cluster                           = aws_ecs_cluster.avr.id
  task_definition                   = module.avr_task_worker.task_definition.arn
  desired_count                     = 1
  enable_execute_command            = true
  launch_type                       = "FARGATE"
  platform_version                  = "1.4.0"

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets          = data.aws_subnet_ids.stack_private_subnets.ids
    security_groups  = [
      aws_security_group.avr.id, 
      data.aws_security_group.stack_db_client_security_group.id
    ]
    assign_public_ip = false
  }

  tags = var.tags
}
