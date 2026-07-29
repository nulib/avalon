locals {
  avr_certificate_domain       = var.avr_certificate_domain == "" ? "*.${trimsuffix(module.core.outputs.vpc.public_dns_zone.name, ".")}" : var.avr_certificate_domain
  domain_host                  = var.domain_host == "" ? "avr.${module.core.outputs.vpc.public_dns_zone.name}" : var.domain_host
  streaming_certificate_domain = var.streaming_certificate_domain == "" ? "*.${trimsuffix(module.core.outputs.vpc.public_dns_zone.name, ".")}" : var.streaming_certificate_domain
}

variable "active_record_encryption" {
  type    = map(string)
}

variable "additional_hosts" {
  type    = string
  default = ""
}

variable "agentless_sso_key" {
  type = string
}

variable "analytics_container_id" {
  type    = string
  default = ""
}

variable "analytics_tracker" {
  type    = string
  default = ""
}

variable "app_name" {
  type    = string
  default = "avr"
}

variable "avr_certificate_domain" {
  type    = string
  default = ""
}

variable "canvas_api_token" {
  type    = string
  default = ""
}

variable "cloudfront_public_key" {
  type = string
}

variable "domain_host" {
  type    = string
  default = ""
}

variable "streaming_certificate_domain" {
  type    = string
  default = ""
}

variable "email_comments" {
  type    = string
  default = "repository@northwestern.edu"
}

variable "email_notification" {
  type    = string
  default = "repository@northwestern.edu"
}

variable "email_support" {
  type    = string
  default = "repository@northwestern.edu"
}

variable "honeybadger_api_key" {
  type    = string
  default = ""
}

variable "initial_user" {
  type = string
}

variable "lti_auth_key" {
  type    = string
  default = ""
}

variable "lti_auth_secret" {
  type    = string
  default = ""
}

variable "streaming_hostname" {
  type    = string
  default = ""
}


variable "tags" {
  type = map(string)
  default = {
    Component = "avr"
    Git       = "github.com/nulib/avalon"
    Project   = "avr"
  }
}
