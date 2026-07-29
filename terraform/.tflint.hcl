tflint {
  required_version = "~> 0.50"
}

config {
  call_module_type = "all"  
}

plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "aws_lambda_function_deprecated_runtime" {
  enabled = false
}

rule "aws_resource_missing_tags" {
  enabled   = true
  tags      = ["Component", "Environment", "Git", "Project"]
}

rule "terraform_module_pinned_source" {
  enabled             = false
  style               = "flexible"
  default_branches    = ["master", "main"]
}