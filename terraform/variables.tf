variable "additional_hostnames" {
  type    = list(string)
  default = []
}

variable "agentless_sso_key" {
  type = string
}

variable "app_name" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "availability_zones" {
  type    = list(any)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "canvas_api_token" {
  type    = string
}

variable "certificate_name" {
  type    = string
  default = "*"
}

variable "cloudfront_public_key" {
  type    = string
}

variable "dns_zone" {
  type    = string
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

variable "environment" {
  type = string
}

variable "honeybadger_api_key" {
  type    = string
  default = ""
}

variable "initial_user" {
  type    = string
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
  type    = map(any)
  default = {}
}

variable "vpc_id" {
  type    = string
}