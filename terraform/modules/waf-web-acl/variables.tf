variable "web_acl_name" {
  description = "Name of the WAFv2 Web ACL"
  type        = string
}

variable "description" {
  description = "Description of the Web ACL"
  type        = string
  default     = null
}

variable "scope" {
  description = "Scope of the Web ACL. Valid values: REGIONAL or CLOUDFRONT"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "default_action" {
  description = "Default action for requests that do not match rules. Valid values: allow or block"
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be allow or block."
  }
}

variable "managed_rule_groups" {
  description = "Managed rule groups to attach to the Web ACL"
  type = list(object({
    name                    = string
    priority                = number
    managed_rule_group_name = string
    vendor_name             = string
    metric_name             = string
    override_action         = optional(string, "none")
    version                 = optional(string)
  }))
  default = []
}

variable "enable_cloudwatch_metrics" {
  description = "Enable CloudWatch metrics for the Web ACL"
  type        = bool
  default     = true
}

variable "enable_sampled_requests" {
  description = "Enable sampled requests for the Web ACL"
  type        = bool
  default     = true
}

variable "metric_name" {
  description = "CloudWatch metric name for the Web ACL visibility configuration"
  type        = string
  default     = "waf-web-acl"
}

variable "resource_arn" {
  description = "ARN of the resource to associate with this Web ACL (ALB, API Gateway, etc). Set null to skip association"
  type        = string
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

variable "name" {
  type        = string
  description = "Name tag for the Web ACL"
}

variable "purpose" {
  type        = string
  description = "Purpose of the Web ACL"
  default     = "Web application protection"
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
    Module           = "waf-web-acl"
    Purpose          = var.purpose
  }
  merged_tags = merge(local.common_tags, var.specifictags)
}
