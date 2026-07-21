resource "aws_apigatewayv2_authorizer" "apigatewayv2_authorizer" {
  api_id           = var.api_id
  authorizer_type  = var.authorizer_type
  name             = var.name
  identity_sources = var.identity_sources

  dynamic "jwt_configuration" {
    for_each = var.jwt_audience != null ? [1] : []
    content {
      audience = var.jwt_audience
      issuer   = var.jwt_issuer
    }
  }
}
