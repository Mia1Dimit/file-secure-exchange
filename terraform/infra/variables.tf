variable "applicationid" {
  description = "Application ID for tagging"
  type        = string
}

variable "applicationname" {
  description = "Application name for tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "iam_roles" {
  description = "IAM role configurations"
  type = map(object({
    name               = string
    assume_role_policy = string
    specifictags       = optional(map(string), {})
    policies = optional(map(object({
      name   = string
      policy = string
    })), {})
    managed_policies = optional(map(object({
      policy_arn = string
    })), {})
  }))
  default = {}
}

variable "lambda_functions" {
  description = "Lambda function configurations"
  type = map(object({
    name                  = string
    handler               = string
    runtime               = string
    timeout               = optional(number, 30)
    memory_size           = optional(number, 128)
    environment_variables = optional(map(string), {})
    source_dir            = string
    output_path           = string
    vpc_config = optional(object({
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
  }))
  default = {}
}

variable "lambda_permissions" {
  description = "Lambda permission configurations for S3 and other triggers"
  type = map(object({
    function_name = string
    statement_id  = optional(string)
    action        = optional(string, "lambda:InvokeFunction")
    principal     = string
    source_arn    = string
  }))
  default = {}
}


variable "s3s" {
  type = map(object({
    name                  = string
    blockpublicacls       = bool
    blockpublicpolicy     = bool
    ignorepublicacls      = bool
    restrictpublicbuckets = bool
    environment           = string
    enable_versioning     = string
    rules = map(object({
      id     = string
      status = string
      expiration = optional(map(object({
        date = optional(string)
        days = optional(number)
      })))
      transition = optional(map(object({
        date          = optional(string)
        days          = optional(number)
        storage_class = string
      })))
      filters = optional(map(object({
        prefix                   = optional(string)
        object_size_greater_than = optional(number)
        object_size_less_than    = optional(number)
      })))
    }))
    notifications = map(object({
      lambda_function = list(object({
        id                  = optional(string)
        lambda_function_arn = string
        events              = list(string)
        filter_prefix       = optional(string)
        filter_suffix       = optional(string)
      }))
    }))
    replication_role = optional(string)
    replication_rules = list(object({
      id     = optional(string)
      status = string
      destination = object({
        bucket = string
      })
    }))
    specifictags = map(string)
  }))
}

variable "dynamodb_tables" {
  description = "DynamoDB table configurations"
  type = map(object({
    table_name   = string
    hash_key     = string
    range_key    = optional(string)
    billing_mode = optional(string, "PAY_PER_REQUEST")
    global_secondary_indexes = optional(list(object({
      name               = string
      hash_key           = string
      range_key          = optional(string)
      projection_type    = optional(string)
      non_key_attributes = optional(list(string))
      read_capacity      = optional(number)
      write_capacity     = optional(number)
    })), [])
    enable_point_in_time_recovery = optional(bool, false)
    ttl_attribute_name            = optional(string)
  }))
  default = {}
}

variable "eventbridge_schedulers" {
  description = "EventBridge Scheduler configurations"
  type = map(object({
    name                      = string
    schedule_expression       = string
    target_lambda_key         = string # Key of the lambda function to target
    input                     = optional(string)
    flexible_time_window_mode = optional(string, "OFF")
    state                     = optional(string, "ENABLED")
  }))
  default = {}
}

variable "kms_keys" {
  description = "KMS key configurations"
  type = map(object({
    description                        = optional(string, "Customer managed KMS key")
    key_usage                          = optional(string, "ENCRYPT_DECRYPT")
    customer_master_key_spec           = optional(string, "SYMMETRIC_DEFAULT")
    bypass_policy_lockout_safety_check = optional(bool, false)
    deletion_window_in_days            = optional(number, 30)
    enable_key_rotation                = optional(bool, true)
    is_enabled                         = optional(bool, true)
    multi_region                       = optional(bool, false)
    policy                             = optional(string)
    alias_name                         = optional(string)
    purpose                            = optional(string, "Encryption")
    specifictags                       = optional(map(string), {})
  }))
  default = {}
}

variable "waf_web_acls" {
  description = "WAFv2 Web ACL configurations"
  type = map(object({
    web_acl_name              = string
    description               = optional(string)
    scope                     = optional(string, "REGIONAL")
    default_action            = optional(string, "allow")
    enable_cloudwatch_metrics = optional(bool, true)
    enable_sampled_requests   = optional(bool, true)
    metric_name               = optional(string, "waf-web-acl")
    resource_arn              = optional(string)
    purpose                   = optional(string, "Web application protection")
    specifictags              = optional(map(string), {})
    managed_rule_groups = optional(list(object({
      name                    = string
      priority                = number
      managed_rule_group_name = string
      vendor_name             = string
      metric_name             = string
      override_action         = optional(string, "none")
      version                 = optional(string)
    })), [])
  }))
  default = {}
}

variable "cognito_user_pools" {
  description = "Cognito User Pool configurations"
  type = map(object({
    pool_name            = string
    app_client_name      = string
    domain_prefix        = optional(string, "")
    callback_urls        = optional(list(string), [])
    logout_urls          = optional(list(string), [])
    allowed_oauth_flows  = optional(list(string), ["code"])
    allowed_oauth_scopes = optional(list(string), ["email", "openid", "profile"])
    specifictags         = optional(map(string), {})
  }))
  default = {}
}
