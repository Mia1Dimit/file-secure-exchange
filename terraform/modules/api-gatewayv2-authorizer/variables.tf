variable "api_id" {
  type        = string
  description = "API Gateway API ID"
}

variable "name" {
  type        = string
  description = "Authorizer name"
}

variable "authorizer_type" {
  type        = string
  description = "Authorizer type (JWT, REQUEST)"
  default     = "JWT"
}

variable "identity_sources" {
  type        = list(string)
  description = "Identity source expression"
  default     = ["$request.header.Authorization"]
}

variable "jwt_audience" {
  type        = list(string)
  description = "JWT audience (Cognito app client ID)"
  default     = null
}

variable "jwt_issuer" {
  type        = string
  description = "JWT issuer URL (Cognito user pool endpoint)"
  default     = null
}

variable "environment" {
  type        = string
  description = "Environment Tag"
}

variable "applicationid" {
  type        = string
  description = "Application_ID Tag"
}

variable "applicationname" {
  type        = string
  description = "Application_Name Tag"
}

variable "specifictags" {
  type        = map(string)
  description = "Specific tags for the resource"
  default     = {}
}

locals {
  common_tags = {
    Application_ID   = var.applicationid
    Application_Name = var.applicationname
    Environment      = var.environment
    Name             = var.name
    Module           = "api-gatewayv2-authorizer"
  }
  merged_tags = merge(local.common_tags, var.specifictags)
}
