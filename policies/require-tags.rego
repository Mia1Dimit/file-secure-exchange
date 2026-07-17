package terraform

import rego.v1

# Policy 5: Require Mandatory Tags
#
# Reasoning: ownership, environment, and sensitivity classification should be
# queryable from the infrastructure layer itself, not tribal knowledge.
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
