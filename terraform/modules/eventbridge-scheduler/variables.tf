variable "name" {
  type = string
}

variable "schedule_expression" {
  type = string
}

variable "target_arn" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "input" {
  type    = string
  default = null
}

variable "flexible_time_window_mode" {
  type    = string
  default = "OFF"
}

variable "state" {
  type    = string
  default = "ENABLED"
}
