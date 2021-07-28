locals {
  settings_prefix = "/${var.app_name}/Settings"
}

resource "aws_ssm_parameter" "auth-configuration-analytics_container_id" {
  count   = var.analytics_container_id == "" ? 0 : 1
  type    = "String"
  name    = "${local.settings_prefix}/analytics_container_id"
  value   = var.analytics_container_id
  }

resource "aws_ssm_parameter" "auth-configuration-analytics_tracker" {
  count   = var.analytics_tracker == "" ? 0 : 1
  type    = "String"
  name    = "${local.settings_prefix}/analytics_tracker"
  value   = var.analytics_tracker
  }

resource "aws_ssm_parameter" "auth-configuration-nu-name" {
  type    = "String"
  name    = "${local.settings_prefix}/auth/configuration/nu/name"
  value   = "Northwestern"
  }

resource "aws_ssm_parameter" "auth-configuration-nu-params-base_url" {
  type    = "String"
  name    = "${local.settings_prefix}/auth/configuration/nu/params/base_url"
  value   = "https://northwestern-prod.apigee.net/agentless-websso/"
  }

resource "aws_ssm_parameter" "auth-configuration-nu-params-consumer_key" {
  type    = "SecureString"
  name    = "${local.settings_prefix}/auth/configuration/nu/params/consumer_key"
  value   = var.agentless_sso_key
  }

resource "aws_ssm_parameter" "auth-configuration-nu-provider" {
  type    = "String"
  name    = "${local.settings_prefix}/auth/configuration/nu/provider"
  value   = "nusso"
  }

resource "aws_ssm_parameter" "bib_retriever-default-retriever_class" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/retriever_class"
  value   = "Avalon::BibRetriever::SRU"
  }

resource "aws_ssm_parameter" "bib_retriever-default-retriever_class_require" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/retriever_class_require"
  value   = "avalon/bib_retriever/sru"
  }

resource "aws_ssm_parameter" "bib_retriever-default-query" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/query"
  value   = "rec.id=%<bib_id>s"
  }

resource "aws_ssm_parameter" "bib_retriever-default-url" {
  type    = "String"
  name    = "${local.settings_prefix}/bib_retriever/default/url"
  value   = "https://na02.alma.exlibrisgroup.com/view/sru/01NWU_INST"
  }

resource "aws_ssm_parameter" "canvas-api-endpoint" {
  type    = "String"
  name    = "${local.settings_prefix}/canvas/api/endpoint"
  value   = "https://canvas.northwestern.edu/"
  }

resource "aws_ssm_parameter" "canvas-api-token" {
  type    = "SecureString"
  name    = "${local.settings_prefix}/canvas/api/token"
  value   = var.canvas_api_token
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

resource "aws_ssm_parameter" "encoding-aiff_lambda" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/aiff_lambda"
  value   = aws_lambda_function.aiff_lambda.arn
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

resource "aws_ssm_parameter" "encoding-mediaconvert-queue" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/media_convert/queue"
  value   = aws_media_convert_queue.transcode_queue.name
  }

resource "aws_ssm_parameter" "encoding-mediaconvert-role" {
  type    = "String"
  name    = "${local.settings_prefix}/encoding/media_convert/role"
  value   = aws_iam_role.transcode_role.arn
  }

resource "aws_ssm_parameter" "ffmpeg-path" {
  type    = "String"
  name    = "${local.settings_prefix}/ffmpeg/path"
  value   = "/usr/bin/ffmpeg"
  }

resource "aws_ssm_parameter" "initial_user" {
  type    = "String"
  name    = "${local.settings_prefix}/initial_user"
  value   = var.initial_user
  }

resource "aws_ssm_parameter" "master_file_management-path" {
  type    = "String"
  name    = "${local.settings_prefix}/master_file_management/path"
  value   = "s3://${aws_s3_bucket.avr_preservation.id}/avalon-masterfiles/"
  }

resource "aws_ssm_parameter" "master_file_management-strategy" {
  type    = "String"
  name    = "${local.settings_prefix}/master_file_management/strategy"
  value   = "delete"
  }

resource "aws_ssm_parameter" "redis-host" {
  type    = "String"
  name    = "${local.settings_prefix}/redis/host"
  value   = module.data_services.outputs.redis.address
  }

resource "aws_ssm_parameter" "redis-port" {
  type    = "String"
  name    = "${local.settings_prefix}/redis/port"
  value   = module.data_services.outputs.redis.port
  }

resource "aws_ssm_parameter" "solr-url" {
  type    = "String"
  name    = "${local.settings_prefix}/solr/url"
  value   = "${module.solrcloud.outputs.solr.endpoint}/avr"
  }

resource "aws_ssm_parameter" "solrcloud" {
  type    = "String"
  name    = "${local.settings_prefix}/solrcloud"
  value   = "true"
  }

resource "aws_ssm_parameter" "streaming-http_base" {
  type    = "String"
  name    = "${local.settings_prefix}/streaming/http_base"
  value   = "https://${coalesce(var.streaming_hostname, aws_route53_record.avr_streaming_cloudfront.fqdn)}/"
  }

resource "aws_ssm_parameter" "streaming-server" {
  type    = "String"
  name    = "${local.settings_prefix}/streaming/server"
  value   = "aws"
  }

resource "aws_ssm_parameter" "streaming-signing_key_id" {
  type    = "SecureString"
  name    = "${local.settings_prefix}/streaming/signing_key_id"
  value   = aws_cloudfront_public_key.avr_stream_public_key.id
  }

resource "aws_ssm_parameter" "streaming-stream_token_ttl" {
  type    = "String"
  name    = "${local.settings_prefix}/streaming/stream_token_ttl"
  value   = "300"
  }

resource "aws_ssm_parameter" "zookeeper-connection_str" {
  type    = "String"
  name    = "${local.settings_prefix}/zookeeper/connection_str"
  value   = local.zookeeper_endpoint
  }