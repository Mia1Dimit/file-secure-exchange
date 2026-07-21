package terraform

import rego.v1

# Policy 2: Require Encryption at Rest
#
# Reasoning: explicit encryption-at-rest is table stakes for sensitive
# documents. Per ADR-0003, the MVP baseline is SSE-S3 (AES256); SSE-KMS is
# accepted but not yet required. This policy will be tightened to require
# SSE-KMS specifically once customer-managed keys land in Phase 4 — until
# then it must not fail against the MVP's actual deployed infrastructure.
# ---------------------------------------------------------------------------

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type == "aws_s3_bucket_server_side_encryption_configuration"
	rules := resource.change.after.rule
	count(rules) == 0

	msg := sprintf(
		"require-encryption: %s defines no server-side encryption rule — S3 objects must be encrypted with SSE-S3 or SSE-KMS",
		[resource.address],
	)
}

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type == "aws_s3_bucket_server_side_encryption_configuration"
	some rule in resource.change.after.rule
	algo := rule.apply_server_side_encryption_by_default.sse_algorithm
	not algo in ["AES256", "aws:kms"]

	msg := sprintf(
		"require-encryption: %s uses unsupported algorithm '%s' — must be AES256 (SSE-S3) or aws:kms (SSE-KMS)",
		[resource.address, algo],
	)
}

deny contains msg if {
	some bucket in input.terraform_plan.resource_changes
	bucket.type == "aws_s3_bucket"

	not has_encryption_config(bucket)

	msg := sprintf(
		"require-encryption: %s has no server-side encryption configuration attached",
		[bucket.address],
	)
}

has_encryption_config(bucket) if {
	some encryption in input.terraform_plan.resource_changes

	encryption.type == "aws_s3_bucket_server_side_encryption_configuration"

	encryption.change.after.bucket == bucket.change.after.bucket
}

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type == "aws_dynamodb_table"
	sse := resource.change.after.server_side_encryption
	count(sse) > 0
	some s in sse
	s.enabled == false

	msg := sprintf(
		"require-encryption: %s has server_side_encryption.enabled=false — DynamoDB encryption must stay on",
		[resource.address],
	)
}

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type == "aws_dynamodb_table"
	not resource.change.after.server_side_encryption

	msg := sprintf(
		"require-encryption: %s has no server_side_encryption block — DynamoDB tables must declare encryption explicitly",
		[resource.address],
	)
}