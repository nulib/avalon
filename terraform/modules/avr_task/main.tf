data "aws_iam_role" "task_execution_role" {
  name = "ecsTaskExecutionRole"
}

resource "aws_ecs_task_definition" "this_task_definition" {
  family                   = "${var.app_name}-${var.container_role}"
  container_definitions    = jsonencode([
    {
      name = "avr"
      image = "nulib/avr:${var.container_config.docker_tag}"
      cpu = var.cpu * 0.9765625
      memoryReservation = var.memory * 0.9765625
      mountPoints = []
      essential = true
      environment = [
        { name = "AWS_REGION",          value = var.container_config.region },
        { name = "CONTAINER_ROLE",      value = var.container_role },
        { name = "DATABASE_URL",        value = var.container_config.database_url },
        { name = "FEDORA_BASE_PATH",    value = var.container_config.fedora_base_path },
        { name = "FEDORA_URL",          value = var.container_config.fedora_url },
        { name = "HONEYBADGER_API_KEY", value = var.container_config.honeybadger_api_key },
        { name = "HONEYBADGER_ENV",     value = var.container_config.honeybadger_environment },
        { name = "LTI_AUTH_KEY",        value = var.container_config.lti_auth_key },
        { name = "LTI_AUTH_SECRET",     value = var.container_config.lti_auth_secret },
        { name = "RACK_ENV",            value = "production" },
        { name = "REDIS_HOST",          value = var.container_config.redis_host },
        { name = "REDIS_PORT",          value = var.container_config.redis_port },
        { name = "REDIS_URL",           value = "redis://${var.container_config.redis_host}:${var.container_config.redis_port}/" },
        { name = "SECRET_KEY_BASE",     value = var.container_config.secret_key_base },
        { name = "SOLR_URL",            value = var.container_config.solr_url },
        { name = "SSM_PARAM_PATH",      value = "/${var.app_name}" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = var.container_config.log_group
          awslogs-region = var.container_config.region
          awslogs-stream-prefix = var.container_role
        }
      }
      portMappings = [
        { 
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      volumesFrom = []
    }
  ])
  task_role_arn            = var.role_arn
  execution_role_arn       = data.aws_iam_role.task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  tags                     = var.tags
}
