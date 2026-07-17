package terraform

import rego.v1

# Policy 5: Require Mandatory Tags
#
# Enforced keys: Application_ID, Application_Name, Environment, Name
# These are set by every module's local.common_tags block and are the
# authoritative ownership/environment signals on this platform.
#
# Reasoning: Application_ID, Application_Name, Environment, and Name must be
# present on every managed resource so that cost attribution, environment
# isolation, and ownership are queryable directly from the infrastructure
# layer — not from tribal knowledge.
# ---------------------------------------------------------------------------

required_tags := ["Application_ID", "Application_Name", "Environment", "Name"]

taggable_types := [
	"aws_s3_bucket",
	"aws_dynamodb_table",
	"aws_lambda_function",
	"aws_iam_role",
	"aws_cognito_user_pool",
]

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type in taggable_types
	tags := object.get(resource.change.after, "tags", {})
	some required in required_tags
	not required in object.keys(tags)

	msg := sprintf(
		"require-tags: %s is missing required tag '%s' — Application_ID, Application_Name, Environment and Name are mandatory on every managed resource",
		[resource.address, required],
	)
}
