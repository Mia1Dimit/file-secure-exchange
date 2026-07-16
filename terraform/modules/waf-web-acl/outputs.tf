output "web_acl_id" {
  description = "ID of the Web ACL"
  value       = aws_wafv2_web_acl.web_acl.id
}

output "web_acl_arn" {
  description = "ARN of the Web ACL"
  value       = aws_wafv2_web_acl.web_acl.arn
}

output "web_acl_name" {
  description = "Name of the Web ACL"
  value       = aws_wafv2_web_acl.web_acl.name
}

output "web_acl_capacity" {
  description = "Current capacity of the Web ACL"
  value       = aws_wafv2_web_acl.web_acl.capacity
}
