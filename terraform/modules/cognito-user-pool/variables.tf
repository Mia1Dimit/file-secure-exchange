variable "pool_name" {
  type = string
}

variable "app_client_name" {
  type = string
}

variable "domain_prefix" {
  type    = string
  default = ""
}

variable "callback_urls" {
  type    = list(string)
  default = []
}

variable "logout_urls" {
  type    = list(string)
  default = []
}

variable "allowed_oauth_flows" {
  type    = list(string)
  default = ["code"]
}

variable "allowed_oauth_scopes" {
  type    = list(string)
  default = ["email", "openid", "profile"]
}

variable "environment" {
  type = string
}

variable "applicationid" {
  type = string
}

variable "applicationname" {
  type = string
}

variable "specifictags" {
  type    = map(string)
  default = {}
}

locals {
  common_tags = {
    Application_ID   = var.applicationid
    Application_Name = var.applicationname
    Environment      = var.environment
    Name             = var.pool_name
    Module           = "cognito-user-pool"
  }
  merged_tags = merge(local.common_tags, var.specifictags)
}
