variable "container_config" {
  type    = map(string)
}

variable "cpu" {
  type    = number
}

variable "memory" {
  type    = number
}

variable "container_role" {
  type    = string
}

variable "role_arn" {
  type    = string
}

variable "app_name" {
  type    = string
}

variable "tags" {
  type    = map(string)
}

