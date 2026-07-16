module "waf_web_acl" {
  source   = "../modules/waf-web-acl"
  for_each = var.waf_web_acls

  web_acl_name              = each.value.web_acl_name
  description               = each.value.description
  scope                     = each.value.scope
  default_action            = each.value.default_action
  managed_rule_groups       = each.value.managed_rule_groups
  enable_cloudwatch_metrics = each.value.enable_cloudwatch_metrics
  enable_sampled_requests   = each.value.enable_sampled_requests
  metric_name               = each.value.metric_name
  resource_arn              = each.value.resource_arn
  purpose                   = each.value.purpose
  specifictags              = each.value.specifictags
  name                      = each.key

  applicationid   = var.applicationid
  applicationname = var.applicationname
  environment     = var.environment
}
