locals {
  # Pass through environment variables from the variable config
  lambda_env_vars = {
    for key, lambda_config in var.lambda_functions : key => lambda_config.environment_variables
  }
}

module "lambda_function" {
  source   = "../modules/lambda-function"
  for_each = var.lambda_functions

  function_name         = each.value.name
  role_arn              = module.aws-iam-role["lambda_execution"].iam_role_arn
  handler               = each.value.handler
  runtime               = each.value.runtime
  timeout               = each.value.timeout
  memory_size           = each.value.memory_size
  architectures         = each.value.architectures
  environment_variables = local.lambda_env_vars[each.key]
  vpc_config            = each.value.vpc_config
  source_dir            = each.value.source_dir
  output_path           = each.value.output_path

  applicationid   = var.applicationid
  applicationname = var.applicationname
  environment     = var.environment
  specifictags    = {}

  depends_on = [module.aws-iam-role]
}
