package terraform

import rego.v1

# Policy 4: Require TLS in Transit
#
# Reasoning: encryption at rest is incomplete without enforced transport
# security. Every document bucket policy must explicitly deny requests where
# aws:SecureTransport is false.
# ---------------------------------------------------------------------------

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type == "aws_s3_bucket"
	not has_tls_deny_policy(resource.address)

	msg := sprintf(
		"require-tls: %s has no bucket policy denying non-TLS requests — must deny access when aws:SecureTransport is false",
		[resource.address],
	)
}

has_tls_deny_policy(bucket_address) if {
	some resource in input.terraform_plan.resource_changes
	resource.type == "aws_s3_bucket_policy"
	resource.change.after.bucket == bucket_address
	policy_doc := json.unmarshal(resource.change.after.policy)
	some statement in policy_doc.Statement
	statement.Effect == "Deny"
	statement.Condition.Bool["aws:SecureTransport"] == "false"
}
