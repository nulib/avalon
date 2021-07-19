locals {
  stack_fedora_url            = "http://fcrepo.${data.aws_route53_zone.stack_private_zone.name}/rest"
  stack_solr_url              = "http://solr.${data.aws_route53_zone.stack_private_zone.name}/solr"
  stack_namespace             = "stack-${var.environment}"
  stack_zookeeper_endpoint    = "zk.${data.aws_route53_zone.stack_private_zone.name}:2181/configs"
}

data "aws_db_instance" "stack_db" {
  db_instance_identifier = "${local.stack_namespace}-db"
}

data "aws_security_group" "stack_db_client_security_group" {
  name = "${local.stack_namespace}-db-client"
}

data "aws_elasticache_cluster" "stack_redis" {
  cluster_id = "${local.stack_namespace}-redis"
}

data "aws_vpc" "stack_vpc" {
  id = var.vpc_id
}

data "aws_subnet_ids" "stack_public_subnets" {
  vpc_id = data.aws_vpc.stack_vpc.id
  filter {
    name   = "tag:SubnetType"
    values = ["public"]
  }
}

data "aws_subnet_ids" "stack_private_subnets" {
  vpc_id = data.aws_vpc.stack_vpc.id
  filter {
    name   = "tag:SubnetType"
    values = ["private"]
  }
}

data "aws_route53_zone" "stack_public_zone" {
  name = "stack.${var.dns_zone}"
}

data "aws_route53_zone" "stack_private_zone" {
  private_zone = true
  name         = "stack.vpc.${var.dns_zone}"
}