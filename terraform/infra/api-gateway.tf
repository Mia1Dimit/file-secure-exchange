# Get current AWS account ID and region for Lambda permissions
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  integrations = {
    for item in flatten([
      for api_key, api in var.api_gtws : [
        for int_key, int in api.integrations : {
          key = int_key
          value = merge(
            { api_id = module.api_definitions[api_key].api_id },
            int,
            # Resolve lambda_key to invoke ARN if lambda_key is provided
            int.lambda_key != null ? {
              integration_uri = module.lambda[int.lambda_key].lambda_function_invoke_arn
            } : {}
          )
        }
      ]
    ]) : item.key => item.value
  }

  routes = {
    for item in flatten([
      for api_key, api in var.api_gtws : [
        for r_key, r in api.routes : {
          key = r_key
          value = merge(
            { api_id = module.api_definitions[api_key].api_id },
            r,
            # Resolve authorizer_key to the real authorizer_id — tfvars
            # cannot hold a computed resource ID directly, same reason
            # lambda_key exists for integrations above.
            r.authorizer_key != null ? {
              authorizer_id = module.api_authorizers[r.authorizer_key].authorizer_id
            } : {}
          )
        }
      ]
    ]) : item.key => item.value
  }

  stages = {
    for item in flatten([
      for api_key, api in var.api_gtws : [
        for s_key, s in api.stages : {
          key   = s_key
          value = merge({ api_id = module.api_definitions[api_key].api_id }, s)
        }
      ]
    ]) : item.key => item.value
  }

  # JWT authorizers per API. cognito_key resolves issuer/audience from the
  # Cognito module the same way lambda_key resolves integration_uri above.
  # The cognito-user-pool module exposes user_pool_id/app_client_id, not a
  # pre-built issuer string, so the issuer URL is constructed here using
  # the standard Cognito endpoint format — this is exactly the same value
  # the pool's own .endpoint attribute would return.
  authorizers = {
    for item in flatten([
      for api_key, api in var.api_gtws : [
        for a_key, a in api.authorizers : {
          key = a_key
          value = merge(
            { api_id = module.api_definitions[api_key].api_id },
            a,
            a.cognito_key != null ? {
              jwt_issuer   = "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${module.cognito_user_pool[a.cognito_key].user_pool_id}"
              jwt_audience = [module.cognito_user_pool[a.cognito_key].app_client_id]
            } : {}
          )
        }
      ]
    ]) : item.key => item.value
  }

  # Lambda permissions for API Gateway — unique Lambda functions that need
  # an aws_lambda_permission allowing apigateway.amazonaws.com to invoke them
  lambda_integrations = {
    for item in flatten([
      for api_key, api in var.api_gtws : [
        for int_key, int in api.integrations :
        int.lambda_key != null ? {
          lambda_key = int.lambda_key
          api_key    = api_key
        } : null
      ]
    ]) : item.lambda_key => item if item != null
  }
}

module "api_definitions" {
  for_each = var.api_gtws
  source   = "../modules/api-gatewayv2-api"

  depends_on = [module.lambda]

  name          = each.value.name
  protocol_type = each.value.protocol_type
  description   = each.value.description

  # Required tagging variables
  environment     = var.environment
  applicationname = var.applicationname
  applicationid   = var.applicationid
  specifictags    = {}
}

# JWT authorizers — must exist before routes that reference them.
module "api_authorizers" {
  for_each = local.authorizers
  source   = "../modules/api-gatewayv2-authorizer"

  depends_on = [module.api_definitions, module.cognito_user_pool]

  api_id           = each.value.api_id
  name             = each.value.name
  authorizer_type  = each.value.authorizer_type
  identity_sources = each.value.identity_sources
  jwt_audience     = each.value.jwt_audience
  jwt_issuer       = each.value.jwt_issuer
}

module "api_integrations" {
  for_each = local.integrations
  source   = "../modules/api-gatewayv2-integration"

  depends_on = [module.lambda, module.api_definitions]

  api_id                  = each.value.api_id
  integration_type        = each.value.integration_type
  integration_method      = each.value.integration_method
  integration_uri         = each.value.integration_uri
  payload_format_version  = each.value.payload_format_version
  timeout_milliseconds    = each.value.timeout_milliseconds
  description             = each.value.description
}

module "api_routes" {
  for_each = local.routes
  source   = "../modules/api-gatewayv2-route"

  depends_on = [module.api_integrations, module.api_authorizers]

  api_id              = each.value.api_id
  route_key           = each.value.route_key
  target              = "integrations/${module.api_integrations[each.value.integration_key].id}"
  authorization_type  = each.value.authorization_type
  authorizer_id       = try(each.value.authorizer_id, null)
}

module "api_stages" {
  for_each = local.stages
  source   = "../modules/api-gatewayv2-stage"

  depends_on = [module.api_routes]

  api_id      = each.value.api_id
  name        = each.value.name
  description = each.value.description
  auto_deploy = each.value.auto_deploy

  # Required tagging variables
  environment     = var.environment
  applicationname = var.applicationname
  applicationid   = var.applicationid
  specifictags    = {}
}

# -----------------------------------------------------------------------------
# Lambda Permissions for API Gateway
# -----------------------------------------------------------------------------
# Allow API Gateway to invoke Lambda functions
module "api_gateway_lambda_permissions" {
  for_each = local.lambda_integrations
  source   = "../modules/lambda-permission"

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda[each.key].lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # Allow any stage/route of this API to invoke Lambda (execute-api ARN,
  # not control plane). Uses the provider's actual region via data source
  # rather than a hardcoded region string — avoids the class of bug where
  # a copy-pasted region silently doesn't match where the API actually
  # deploys.
  # Format: arn:aws:execute-api:region:account-id:api-id/stage/method/path
  # Wildcard: arn:aws:execute-api:region:account-id:api-id/*/*/*
  source_arn = "arn:aws:execute-api:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${module.api_definitions[each.value.api_key].api_id}/*/*/*"

  # Not using function URL auth
  function_url_auth_type = null
}
