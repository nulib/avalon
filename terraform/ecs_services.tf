locals {
  avr_urls = [for hostname in concat([aws_route53_record.app_hostname.fqdn], local.secrets.additional_hostnames) : "//${hostname}"]

  container_config = {
    active_storage_bucket     = aws_s3_bucket.avr_active_storage.bucket
    app_name                  = local.secrets.app_name
    aws_region                = local.aws_region
    database_url              = "postgresql://${local.secrets.app_name}:${module.db_schema.password}@${module.data_services.outputs.postgres.address}:${module.data_services.outputs.postgres.port}/${local.secrets.app_name}"
    docker_tag                = terraform.workspace
    fedora_base_path          = "/${local.secrets.app_name}"
    fedora_url                = module.fcrepo.outputs.endpoint
    honeybadger_api_key       = local.secrets.honeybadger_api_key
    honeybadger_environment   = substr(module.core.outputs.stack.namespace, -1, -1) == "s" ? "staging" : "production"
    host_name                 = aws_route53_record.app_hostname.fqdn
    log_group                 = aws_cloudwatch_log_group.avr_logs.name
    lti_auth_key              = local.secrets.lti_auth_key
    lti_auth_secret           = local.secrets.lti_auth_secret
    mediaconvert_queue        = aws_media_convert_queue.transcode_queue.arn
    mediaconvert_role         = aws_iam_role.transcode_role.arn
    preservation_bucket       = aws_s3_bucket.avr_preservation.bucket
    redis_host                = module.data_services.outputs.redis.address
    redis_port                = module.data_services.outputs.redis.port
    region                    = local.aws_region
    secret_key_base           = random_string.secret_key_base.result
    solr_cluster_size         = module.solrcloud.outputs.solr.cluster_size
    solr_url                  = "${module.solrcloud.outputs.solr.endpoint}/avr"
    streaming_url             = "https://${aws_route53_record.avr_streaming_cloudfront.fqdn}/"
    zookeeper_endpoint        = local.zookeeper_endpoint
  }
}

module "db_schema" {
  source        = "git::https://github.com/nulib/infrastructure.git//modules/dbschema"
  schema        = local.secrets.app_name
  aws_region    = local.aws_region
  state_bucket  = "nulterra-state-sandbox"
}

module "avr_task_webapp" {
  source           = "./modules/avr_task"
  container_config = local.container_config
  cpu              = 2048
  memory           = 4096
  container_role   = "webapp"
  role_arn         = aws_iam_role.avr_role.arn
  app_name         = local.secrets.app_name
  tags             = local.tags
}

resource "aws_ecs_service" "avr_webapp" {
  name                              = "${local.secrets.app_name}-webapp"
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
    subnets          = module.core.outputs.vpc.private_subnets.ids
    security_groups  = [
      aws_security_group.avr.id,
      module.solrcloud.outputs.solr.client_security_group,
      module.solrcloud.outputs.zookeeper.client_security_group,
      module.data_services.outputs.postgres.client_security_group,
      module.data_services.outputs.redis.client_security_group
    ]
    assign_public_ip = false
  }

  tags = local.tags
}

module "avr_task_worker" {
  source           = "./modules/avr_task"
  container_config = local.container_config
  cpu              = 2048
  memory           = 4096
  container_role   = "worker"
  role_arn         = aws_iam_role.avr_role.arn
  app_name         = local.secrets.app_name
  tags             = local.tags
}

resource "aws_ecs_service" "avr_worker" {
  name                              = "${local.secrets.app_name}-worker"
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
    subnets          = module.core.outputs.vpc.private_subnets.ids
    security_groups  = [
      aws_security_group.avr.id,
      module.solrcloud.outputs.solr.client_security_group,
      module.solrcloud.outputs.zookeeper.client_security_group,
      module.data_services.outputs.postgres.client_security_group,
      module.data_services.outputs.redis.client_security_group
    ]
    assign_public_ip = false
  }

  tags = local.tags
}
