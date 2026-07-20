module "kms_key" {
  source   = "../modules/kms-key"
  for_each = var.kms_keys

  description                        = each.value.description
  key_usage                          = each.value.key_usage
  customer_master_key_spec           = each.value.customer_master_key_spec
  bypass_policy_lockout_safety_check = each.value.bypass_policy_lockout_safety_check
  deletion_window_in_days            = each.value.deletion_window_in_days
  enable_key_rotation                = each.value.enable_key_rotation
  is_enabled                         = each.value.is_enabled
  multi_region                       = each.value.multi_region
  policy                             = each.value.policy
  alias_name                         = each.value.alias_name
  purpose                            = each.value.purpose
  specifictags                       = each.value.specifictags
  name                               = each.key

  applicationid   = var.applicationid
  applicationname = var.applicationname
  environment     = var.environment
}
