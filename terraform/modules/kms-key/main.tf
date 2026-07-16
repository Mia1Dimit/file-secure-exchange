resource "aws_kms_key" "kms_key" {
  description                        = var.description
  key_usage                          = var.key_usage
  customer_master_key_spec           = var.customer_master_key_spec
  bypass_policy_lockout_safety_check = var.bypass_policy_lockout_safety_check
  deletion_window_in_days            = var.deletion_window_in_days
  enable_key_rotation                = var.enable_key_rotation
  is_enabled                         = var.is_enabled
  multi_region                       = var.multi_region
  policy                             = var.policy

  tags = local.merged_tags
}

resource "aws_kms_alias" "kms_alias" {
  count = var.alias_name != null ? 1 : 0

  name          = var.alias_name
  target_key_id = aws_kms_key.kms_key.key_id
}
