output "key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.kms_key.key_id
}

output "key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.kms_key.arn
}

output "key_policy" {
  description = "Policy of the KMS key"
  value       = aws_kms_key.kms_key.policy
}

output "alias_name" {
  description = "Alias name assigned to the KMS key, if created"
  value       = length(aws_kms_alias.kms_alias) > 0 ? aws_kms_alias.kms_alias[0].name : null
}

output "alias_arn" {
  description = "Alias ARN assigned to the KMS key, if created"
  value       = length(aws_kms_alias.kms_alias) > 0 ? aws_kms_alias.kms_alias[0].arn : null
}
