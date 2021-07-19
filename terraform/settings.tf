locals {
  settings_prefix = "/${var.app_name}/Settings"
}

resource "aws_ssm_parameter" "auth-configuration-nu-name" {
  type  = "String"
  name  = "${local.settings_prefix}/auth/configuration/nu/name"
  value = "Northwestern"
}

resource "aws_ssm_parameter" "auth-configuration-nu-params-base_url" {
  type  = "String"
  name  = "${local.settings_prefix}/auth/configuration/nu/params/base_url"
  value = "https://northwestern-prod.apigee.net/agentless-websso/"
}

resource "aws_ssm_parameter" "auth-configuration-nu-provider" {
  type  = "String"
  name  = "${local.settings_prefix}/auth/configuration/nu/provider"
  value = "nusso"
}

resource "aws_ssm_parameter" "bib_retriever-default-attribute" {
  type  = "String"
  name  = "${local.settings_prefix}/bib_retriever/default/attribute"
  value = "12"
}

resource "aws_ssm_parameter" "bib_retriever-default-database" {
  type  = "String"
  name  = "${local.settings_prefix}/bib_retriever/default/database"
  value = "01NWU_INST"
}

resource "aws_ssm_parameter" "bib_retriever-default-host" {
  type  = "String"
  name  = "${local.settings_prefix}/bib_retriever/default/host"
  value = "na02.alma.exlibrisgroup.com"
}

resource "aws_ssm_parameter" "bib_retriever-default-port" {
  type  = "String"
  name  = "${local.settings_prefix}/bib_retriever/default/port"
  value = 1921
}

resource "aws_ssm_parameter" "bib_retriever-default-protocol" {
  type  = "String"
  name  = "${local.settings_prefix}/bib_retriever/default/protocol"
  value = "z39.50"
}

resource "aws_ssm_parameter" "bib_retriever-default-retriever_class" {
  type  = "String"
  name  = "${local.settings_prefix}/bib_retriever/default/retriever_class"
  value = "Avalon::BibRetriever::Zoom"
}

resource "aws_ssm_parameter" "bib_retriever-default-retriever_class_require" {
  type  = "String"
  name  = "${local.settings_prefix}/bib_retriever/default/retriever_class_require"
  value = "avalon/bib_retriever/zoom"
}

resource "aws_ssm_parameter" "canvas-api-endpoint" {
  type  = "String"
  name  = "${local.settings_prefix}/canvas/api/endpoint"
  value = "https://canvas.northwestern.edu/"
}

resource "aws_ssm_parameter" "domain-host" {
  type    = "String"
  name    = "${local.settings_prefix}/domain/host"
  value   = local.domain_host
}

resource "aws_ssm_parameter" "domain-port" {
  type    = "String"
  name    = "${local.settings_prefix}/domain/port"
  value   = "443"
}

resource "aws_ssm_parameter" "domain-protocol" {
  type    = "String"
  name    = "${local.settings_prefix}/domain/protocol"
  value   = "https"
}

resource "aws_ssm_parameter" "dropbox-path" {
  type    = "String"
  name    = "${local.settings_prefix}/dropbox/path"
  value   = "s3://${aws_s3_bucket.avr_masterfiles.id}/dropbox/"
}

resource "aws_ssm_parameter" "dropbox-upload_uri" {
  type    = "String"
  name    = "${local.settings_prefix}/dropbox/upload_uri"
  value   = "s3://${aws_s3_bucket.avr_masterfiles.id}/dropbox/"
}

resource "aws_ssm_parameter" "email-mailer" {
  type    = "String"
  name    = "${local.settings_prefix}/email/mailer"
  value   = "aws_sdk"
}

resource "aws_ssm_parameter" "email-comments" {
  type    = "String"
  name    = "${local.settings_prefix}/email/comments"
  value   = var.email_comments
}

resource "aws_ssm_parameter" "email-notification" {
  type    = "String"
  name    = "${local.settings_prefix}/email/notification"
  value   = var.email_notification
}

resource "aws_ssm_parameter" "email-support" {
  type    = "String"
  name    = "${local.settings_prefix}/email/support"
  value   = var.email_support
}

resource "aws_ssm_parameter" "encoding-derivative_bucket" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/derivative_bucket"
  value   = aws_s3_bucket.avr_streaming.id
}

resource "aws_ssm_parameter" "encoding-engine_adapter" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/engine_adapter"
  value   = "media_convert"
}

resource "aws_ssm_parameter" "encoding-manage_derivatives" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/manage_derivatives"
  value   = "false"
}

resource "aws_ssm_parameter" "encoding-masterfile_bucket" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/masterfile_bucket"
  value   = aws_s3_bucket.avr_masterfiles.id
}

resource "aws_ssm_parameter" "encoding-mediaconvert-role" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/media_convert/role"
  value   = aws_iam_role.transcode_role.arn
}

resource "aws_ssm_parameter" "initial_user" {
  type    = "String"
  name    = "${local.settings_prefix}/initial_user"
  value   = var.initial_user
}

resource "aws_ssm_parameter" "master_file_management-path" {
  type  = "String"
  name  = "${local.settings_prefix}/master_file_management/path"
  value = "s3://${aws_s3_bucket.avr_preservation.id}/avalon-masterfiles/"
}

resource "aws_ssm_parameter" "master_file_management-strategy" {
  type  = "String"
  name  = "${local.settings_prefix}/master_file_management/strategy"
  value = "move"
}

resource "aws_ssm_parameter" "redis-host" {
  type  = "String"
  name  = "${local.settings_prefix}/redis/host"
  value = data.aws_elasticache_cluster.stack_redis.cache_nodes.0.address
}

resource "aws_ssm_parameter" "redis-port" {
  type  = "String"
  name  = "${local.settings_prefix}/redis/port"
  value = data.aws_elasticache_cluster.stack_redis.cache_nodes.0.port
}

resource "aws_ssm_parameter" "solr-url" {
  type    = "String"
  name    = "${local.settings_prefix}/solr/url"
  value   = "${local.stack_solr_url}/avr"
}

resource "aws_ssm_parameter" "solrcloud" {
  type  = "String"
  name  = "${local.settings_prefix}/solrcloud"
  value = "true"
}

resource "aws_ssm_parameter" "streaming-http_base" {
  type    = "String"
  name    = "${local.settings_prefix}/streaming/http_base"
  value   = "https://${coalesce(var.streaming_hostname, aws_route53_record.avr_streaming_cloudfront.fqdn)}/"
}

resource "aws_ssm_parameter" "streaming-server" {
  type  = "String"
  name  = "${local.settings_prefix}/streaming/server"
  value = "aws"
}

resource "aws_ssm_parameter" "streaming-signing_key_id" {
  type  = "String"
  name  = "${local.settings_prefix}/streaming/signing_key_id"
  value = aws_cloudfront_public_key.avr_stream_public_key.id
}

resource "aws_ssm_parameter" "streaming-stream_token_ttl" {
  type  = "String"
  name  = "${local.settings_prefix}/streaming/stream_token_ttl"
  value = "300"
}

resource "aws_ssm_parameter" "zookeeper-connection_str" {
  type    = "String"
  name    = "${local.settings_prefix}/zookeeper/connection_str"
  value   = local.stack_zookeeper_endpoint
}