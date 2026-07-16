output "user_pool_id" { value = aws_cognito_user_pool.cognito_user_pool.id }
output "user_pool_arn" { value = aws_cognito_user_pool.cognito_user_pool.arn }
output "app_client_id" { value = aws_cognito_user_pool_client.cognito_user_pool_client.id }
output "hosted_ui_domain" { value = length(aws_cognito_user_pool_domain.cognito_user_pool_domain) > 0 ? aws_cognito_user_pool_domain.cognito_user_pool_domain[0].domain : null }
