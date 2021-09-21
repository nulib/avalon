data "aws_region" "current" { }

locals {
  secrets = module.secrets.vars
  aws_region = data.aws_region.current.name
}

module "secrets" {
  source    = "git::https://github.com/nulib/infrastructure.git//modules/secrets"
  path      = "avr"
  defaults  = jsonencode({
    additional_hostnames    = []
    aws_region              = "us-east-1"
    availability_zones      = ["us-east-1a", "us-east-1b", "us-east-1c"]
    certificate_name        = "*"
    email_comments          = "repository@northwestern.edu"
    email_notification      = "repository@northwestern.edu"
    email_support           = "repository@northwestern.edu"
    honeybadger_api_key     = ""
    lti_auth_key            = ""
    lti_auth_secret         = ""
    streaming_hostname      = ""

    tags = {
      Component = "avr"
      Git       = "github.com/nulib/avalon"
      Project   = "avr"
    }
  })
}
