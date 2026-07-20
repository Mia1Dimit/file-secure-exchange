package terraform

import rego.v1

deny contains msg if {
	some bucket in input.terraform_plan.resource_changes
	bucket.type == "aws_s3_bucket"
	not has_tls_deny_policy(bucket)

	msg := sprintf(
		"require-tls: %s has no bucket policy denying non-TLS requests — must deny access when aws:SecureTransport is false",
		[bucket.address],
	)
}

has_tls_deny_policy(bucket_resource) if {
	some policy in input.terraform_plan.resource_changes
	policy.type == "aws_s3_bucket_policy"
	object.get(policy, "module_address", "") == object.get(bucket_resource, "module_address", "")

	doc := json.unmarshal(policy.change.after.policy)
	some stmt in doc.Statement
	stmt.Effect == "Deny"
	stmt.Condition.Bool["aws:SecureTransport"] == "false"
}
