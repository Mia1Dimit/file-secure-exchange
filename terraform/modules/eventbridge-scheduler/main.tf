resource "aws_scheduler_schedule" "scheduler_schedule" {
  name                = var.name
  schedule_expression = var.schedule_expression
  state               = var.state

  flexible_time_window {
    mode = var.flexible_time_window_mode
  }

  target {
    arn      = var.target_arn
    role_arn = var.role_arn
    input    = var.input
  }
}