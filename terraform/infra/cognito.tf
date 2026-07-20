module "cognito_user_pool" {
  source   = "../modules/cognito-user-pool"
  for_each = var.cognito_user_pools

  pool_name            = each.value.pool_name
  app_client_name      = each.value.app_client_name
  domain_prefix        = each.value.domain_prefix
  callback_urls        = each.value.callback_urls
  logout_urls          = each.value.logout_urls
  allowed_oauth_flows  = each.value.allowed_oauth_flows
  allowed_oauth_scopes = each.value.allowed_oauth_scopes
  specifictags         = each.value.specifictags

  applicationid   = var.applicationid
  applicationname = var.applicationname
  environment     = var.environment
}
