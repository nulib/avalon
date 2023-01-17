locals {
  settings_prefix = "/${var.app_name}/Settings"
}

resource "aws_ssm_parameter" "auth-configuration-analytics_container_id" {
  count   = var.analytics_container_id == "" ? 0 : 1
  type    = "String"
  name    = "${local.settings_prefix}/analytics_container_id"
  value   = var.analytics_container_id
  tags    = local.tags
}

resource "aws_ssm_parameter" "auth-configuration-analytics_tracker" {
  count   = var.analytics_tracker == "" ? 0 : 1
  type    = "String"
  name    = "${local.settings_prefix}/analytics_tracker"
  value   = var.analytics_tracker
  tags    = local.tags
}

resource "aws_ssm_parameter" "auth-configuration-nu-name" {
  type    = "String"
  name    = "${local.settings_prefix}/auth/configuration/nu/name"
  value   = "Northwestern"
  tags    = local.tags
}

resource "aws_ssm_parameter" "auth-configuration-nu-params-base_url" {
  type    = "String"
  name    = "${local.settings_prefix}/auth/configuration/nu/params/base_url"
  value   = "https://northwestern-prod.apigee.net/agentless-websso/"
  tags    = local.tags
}

resource "aws_ssm_parameter" "auth-configuration-nu-params-consumer_key" {
  type    = "SecureString"
  name    = "${local.settings_prefix}/auth/configuration/nu/params/consumer_key"
  value   = var.agentless_sso_key
  tags    = local.tags
}

resource "aws_ssm_parameter" "auth-configuration-nu-provider" {
  type    = "String"
  name    = "${local.settings_prefix}/auth/configuration/nu/provider"
  value   = "nusso"
  tags    = local.tags
}

resource "aws_ssm_parameter" "bib_retriever-default-attribute" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/attribute"
  value   = "12"
  tags    = local.tags
}

resource "aws_ssm_parameter" "bib_retriever-default-database" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/database"
  value   = "01NWU_INST"
  tags    = local.tags
}

resource "aws_ssm_parameter" "bib_retriever-default-host" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/host"
  value   = "na02.alma.exlibrisgroup.com"
  tags    = local.tags
}

resource "aws_ssm_parameter" "bib_retriever-default-port" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/port"
  value   = 1921
  tags    = local.tags
}

resource "aws_ssm_parameter" "bib_retriever-default-protocol" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/protocol"
  value   = "z39.50"
  tags    = local.tags
}

resource "aws_ssm_parameter" "bib_retriever-default-retriever_class" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/retriever_class"
  value   = "Avalon::BibRetriever::Zoom"
  tags    = local.tags
}

resource "aws_ssm_parameter" "bib_retriever-default-retriever_class_require" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/retriever_class_require"
  value   = "avalon/bib_retriever/zoom"
  tags    = local.tags
}

resource "aws_ssm_parameter" "canvas-api-endpoint" {
  type    = "String"
  name    = "${local.settings_prefix}/canvas/api/endpoint"
  value   = "https://canvas.northwestern.edu/"
  tags    = local.tags
}

resource "aws_ssm_parameter" "canvas-api-token" {
  type    = "SecureString"
  name    = "${local.settings_prefix}/canvas/api/token"
  value   = var.canvas_api_token
  tags    = local.tags
}

resource "aws_ssm_parameter" "domain-host" {
  type    = "String"
  name    = "${local.settings_prefix}/domain/host"
  value   = local.domain_host
  tags    = local.tags
}

resource "aws_ssm_parameter" "domain-port" {
  type    = "String"
  name    = "${local.settings_prefix}/domain/port"
  value   = "443"
  tags    = local.tags
}

resource "aws_ssm_parameter" "domain-protocol" {
  type    = "String"
  name    = "${local.settings_prefix}/domain/protocol"
  value   = "https"
  tags    = local.tags
}

resource "aws_ssm_parameter" "dropbox-path" {
  type    = "String"
  name    = "${local.settings_prefix}/dropbox/path"
  value   = "s3://${aws_s3_bucket.avr_masterfiles.id}/dropbox/"
  tags    = local.tags
}

resource "aws_ssm_parameter" "dropbox-upload_uri" {
  type    = "String"
  name    = "${local.settings_prefix}/dropbox/upload_uri"
  value   = "s3://${aws_s3_bucket.avr_masterfiles.id}/dropbox/"
  tags    = local.tags
}

resource "aws_ssm_parameter" "email-mailer" {
  type    = "String"
  name    = "${local.settings_prefix}/email/mailer"
  value   = "aws_sdk"
  tags    = local.tags
}

resource "aws_ssm_parameter" "email-comments" {
  type    = "String"
  name    = "${local.settings_prefix}/email/comments"
  value   = var.email_comments
  tags    = local.tags
}

resource "aws_ssm_parameter" "email-notification" {
  type    = "String"
  name    = "${local.settings_prefix}/email/notification"
  value   = var.email_notification
  tags    = local.tags
}

resource "aws_ssm_parameter" "email-support" {
  type    = "String"
  name    = "${local.settings_prefix}/email/support"
  value   = var.email_support
  tags    = local.tags
}

resource "aws_ssm_parameter" "encoding-aiff_lambda" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/aiff_lambda"
  value   = aws_lambda_function.aiff_lambda.arn
  tags    = local.tags
}

resource "aws_ssm_parameter" "encoding-aiff_lambda" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/aiff_lambda"
  value   = aws_lambda_function.aiff_lambda.arn
  tags    = local.tags
}

resource "aws_ssm_parameter" "encoding-derivative_bucket" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/derivative_bucket"
  value   = aws_s3_bucket.avr_streaming.id
  tags    = local.tags
}

resource "aws_ssm_parameter" "encoding-engine_adapter" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/engine_adapter"
  value   = "media_convert"
  tags    = local.tags
}

resource "aws_ssm_parameter" "encoding-manage_derivatives" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/manage_derivatives"
  value   = "false"
  tags    = local.tags
}

resource "aws_ssm_parameter" "encoding-masterfile_bucket" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/masterfile_bucket"
  value   = aws_s3_bucket.avr_masterfiles.id
  tags    = local.tags
}

resource "aws_ssm_parameter" "encoding-mediaconvert-queue" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/media_convert/queue"
  value   = aws_media_convert_queue.transcode_queue.name
  tags    = local.tags
}

resource "aws_ssm_parameter" "encoding-mediaconvert-role" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/media_convert/role"
  value   = aws_iam_role.transcode_role.arn
  tags    = local.tags
}

resource "aws_ssm_parameter" "initial_user" {
  type    = "String"
  name    = "${local.settings_prefix}/initial_user"
  value   = var.initial_user
  tags    = local.tags
}

resource "aws_ssm_parameter" "master_file_management-path" {
  type    = "String"
  name    = "${local.settings_prefix}/master_file_management/path"
  value   = "s3://${aws_s3_bucket.avr_preservation.id}/avalon-masterfiles/"
  tags    = local.tags
}

resource "aws_ssm_parameter" "master_file_management-strategy" {
  type    = "String"
  name    = "${local.settings_prefix}/master_file_management/strategy"
  value   = "move"
  tags    = local.tags
}

resource "aws_ssm_parameter" "redis-host" {
  type    = "String"
  name    = "${local.settings_prefix}/redis/host"
  value   = module.data_services.outputs.redis.address
  tags    = local.tags
}

resource "aws_ssm_parameter" "redis-port" {
  type    = "String"
  name    = "${local.settings_prefix}/redis/port"
  value   = module.data_services.outputs.redis.port
  tags    = local.tags
}

resource "aws_ssm_parameter" "solr-url" {
  type    = "String"
  name    = "${local.settings_prefix}/solr/url"
  value   = "${module.solrcloud.outputs.solr.endpoint}/avr"
  tags    = local.tags
}

resource "aws_ssm_parameter" "solrcloud" {
  type    = "String"
  name    = "${local.settings_prefix}/solrcloud"
  value   = "true"
  tags    = local.tags
}

resource "aws_ssm_parameter" "streaming-http_base" {
  type    = "String"
  name    = "${local.settings_prefix}/streaming/http_base"
  value   = "https://${coalesce(var.streaming_hostname, aws_route53_record.avr_streaming_cloudfront.fqdn)}/"
  tags    = local.tags
}

resource "aws_ssm_parameter" "streaming-server" {
  type    = "String"
  name    = "${local.settings_prefix}/streaming/server"
  value   = "aws"
  tags    = local.tags
}

resource "aws_ssm_parameter" "streaming-signing_key_id" {
  type    = "SecureString"
  name    = "${local.settings_prefix}/streaming/signing_key_id"
  value   = aws_cloudfront_public_key.avr_stream_public_key.id
  tags    = local.tags
}

resource "aws_ssm_parameter" "streaming-stream_token_ttl" {
  type    = "String"
  name    = "${local.settings_prefix}/streaming/stream_token_ttl"
  value   = "300"
  tags    = local.tags
}

resource "aws_ssm_parameter" "zookeeper-connection_str" {
  type    = "String"
  name    = "${local.settings_prefix}/zookeeper/connection_str"
  value   = local.zookeeper_endpoint
  tags    = local.tags
}