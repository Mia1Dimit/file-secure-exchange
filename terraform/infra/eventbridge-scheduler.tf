module "eventbridge_scheduler" {
  source   = "../modules/eventbridge-scheduler"
  for_each = var.eventbridge_schedulers

  name                      = each.value.name
  schedule_expression       = each.value.schedule_expression
  target_arn                = module.lambda_function[each.value.target_lambda_key].lambda_function_arn
  role_arn                  = module.aws-iam-role["scheduler_execution"].iam_role_arn
  input                     = each.value.input
  flexible_time_window_mode = each.value.flexible_time_window_mode
  state                     = each.value.state

  depends_on = [module.lambda_function, module.aws-iam-role]
}
