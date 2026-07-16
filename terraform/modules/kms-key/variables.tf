variable "description" {
  description = "Description for the KMS key"
  type        = string
  default     = "Customer managed KMS key"
}

variable "key_usage" {
  description = "Specifies the intended use of the key"
  type        = string
  default     = "ENCRYPT_DECRYPT"
}

variable "customer_master_key_spec" {
  description = "Specifies whether the key contains a symmetric key or an asymmetric key pair"
  type        = string
  default     = "SYMMETRIC_DEFAULT"
}

variable "bypass_policy_lockout_safety_check" {
  description = "Whether to bypass the policy lockout safety check"
  type        = bool
  default     = false
}

variable "deletion_window_in_days" {
  description = "Waiting period, specified in number of days, after which KMS key is deleted"
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "enable_key_rotation" {
  description = "Specifies whether key rotation is enabled"
  type        = bool
  default     = true
}

variable "is_enabled" {
  description = "Specifies whether the key is enabled"
  type        = bool
  default     = true
}

variable "multi_region" {
  description = "Indicates whether the KMS key is a multi-region key"
  type        = bool
  default     = false
}

variable "policy" {
  description = "A valid policy JSON document for the KMS key"
  type        = string
  default     = null
}

variable "alias_name" {
  description = "Alias for the key in the format alias/your-key-name. Set null to skip alias creation"
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
  description = "Name tag for the key"
}

variable "purpose" {
  type        = string
  description = "Purpose of the KMS key"
  default     = "Encryption"
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
    Module           = "kms-key"
    Purpose          = var.purpose
  }
  merged_tags = merge(local.common_tags, var.specifictags)
}
