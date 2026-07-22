resource "aws_cognito_user_pool" "cognito_user_pool" {
  name = var.pool_name
  tags = local.merged_tags
}

resource "aws_cognito_user_pool_client" "cognito_user_pool_client" {
  name                                 = var.app_client_name
  user_pool_id                         = aws_cognito_user_pool.cognito_user_pool.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = var.allowed_oauth_flows
  allowed_oauth_scopes                 = var.allowed_oauth_scopes
  explicit_auth_flows                  = var.explicit_auth_flows
  callback_urls                        = var.callback_urls
  logout_urls                          = var.logout_urls
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "cognito_user_pool_domain" {
  count        = var.domain_prefix != "" ? 1 : 0
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.cognito_user_pool.id
}
