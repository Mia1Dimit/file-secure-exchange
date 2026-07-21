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
    architectures         = optional(list(string), ["arm64"])
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

variable "api_gtws" {
  description = "Map of API definitions"
  type = map(object({
    name                         = string
    protocol_type                = string
    api_key_selection_expression = optional(string)
    credentials_arn              = optional(string)
    description                  = optional(string)
    disable_execute_api_endpoint = optional(bool)
    route_key                    = optional(string)
    route_selection_expression   = optional(string)
    target                       = optional(string)
    api_version                  = optional(string)
    body                         = optional(string)
    fail_on_warnings             = optional(bool)
    integrations = map(object({
      integration_type          = string
      connection_id             = optional(string)
      connection_type           = optional(string)
      content_handling_strategy = optional(string)
      credentials_arn           = optional(string)
      description                = optional(string)
      integration_method         = optional(string)
      integration_subtype        = optional(string)
      integration_uri            = optional(string)
      lambda_key                 = optional(string) # Key to lookup Lambda invoke ARN
      passthrough_behavior       = optional(string)
      payload_format_version     = optional(string)
      request_parameters         = optional(map(string))
      request_templates          = optional(map(string))
      response_parameters = optional(list(object({
        mappings    = map(string)
        status_code = string
      })))
      template_selection_expression = optional(string)
      timeout_milliseconds          = optional(number)
      tls_config = optional(object({
        server_name_to_verify = optional(string)
      }))
    }))
    # JWT authorizers for this API. cognito_key resolves jwt_issuer/jwt_audience
    # against var.cognito_user_pools in apigateway.tf's locals.authorizers —
    # set jwt_issuer/jwt_audience directly instead if this authorizer isn't
    # backed by a Cognito pool managed in this same tfvars file.
    authorizers = optional(map(object({
      name             = string
      authorizer_type  = optional(string, "JWT")
      identity_sources = optional(list(string), ["$request.header.Authorization"])
      cognito_key      = optional(string)
      jwt_issuer       = optional(string)
      jwt_audience     = optional(list(string))
    })), {})
    routes = map(object({
      route_key                  = string
      integration_key            = optional(string) # Key to lookup integration
      authorizer_key              = optional(string) # Key to lookup authorizer — resolves to authorizer_id
      api_key_required            = optional(bool)
      authorization_scopes        = optional(list(string))
      authorization_type          = optional(string)
      authorizer_id                = optional(string) # kept for direct/manual use if ever needed
      model_selection_expression  = optional(string)
      operation_name              = optional(string)
      request_models               = optional(map(string))
      request_parameters = optional(list(object({
        request_parameter_key = string
        required               = bool
      })))
      route_response_selection_expression = optional(string)
      target                               = optional(string)
    }))
    stages = map(object({
      name                  = string
      auto_deploy           = optional(bool)
      client_certificate_id = optional(string)
      deployment_id         = optional(string)
      description           = optional(string)
      stage_variables        = optional(map(string))
      access_log_settings = optional(object({
        destination_arn = string
        format          = string
      }))
      default_route_settings = optional(object({
        data_trace_enabled       = optional(bool)
        detailed_metrics_enabled = optional(bool)
        logging_level             = optional(string)
        throttling_burst_limit    = optional(number)
        throttling_rate_limit     = optional(number)
      }))
      route_settings = optional(object({
        route_key                = string
        data_trace_enabled       = optional(bool)
        detailed_metrics_enabled = optional(bool)
        logging_level             = optional(string)
        throttling_burst_limit    = optional(number)
        throttling_rate_limit     = optional(number)
      }))
      specifictags = optional(map(string))
      environment   = optional(string)
    }))
    specifictags = optional(map(string))
    environment   = optional(string)
  }))
}
