package terraform

import rego.v1

# Policy 3: Deny IAM Wildcards
#
# Reasoning: wildcard IAM is a frequent audit finding and should be
# mechanically blocked rather than caught in review. No "*" on Action or
# Resource in any policy attached to a runtime role (Lambda, ECS, etc.).
# ---------------------------------------------------------------------------

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type in ["aws_iam_policy", "aws_iam_role_policy"]
	policy_doc := json.unmarshal(resource.change.after.policy)
	some statement in policy_doc.Statement
	statement.Effect == "Allow"
	action_is_wildcard(statement.Action)

	msg := sprintf(
		"deny-iam-wildcard: %s grants wildcard Action — runtime roles must be scoped to specific actions",
		[resource.address],
	)
}

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type in ["aws_iam_policy", "aws_iam_role_policy"]
	policy_doc := json.unmarshal(resource.change.after.policy)
	some statement in policy_doc.Statement
	statement.Effect == "Allow"
	resource_is_wildcard(statement.Resource)

	msg := sprintf(
		"deny-iam-wildcard: %s grants wildcard Resource — runtime roles must be scoped to specific ARNs",
		[resource.address],
	)
}

action_is_wildcard(action) if {
	action == "*"
}

action_is_wildcard(action) if {
	some a in action
	a == "*"
}

resource_is_wildcard(res) if {
	res == "*"
}

resource_is_wildcard(res) if {
	some r in res
	r == "*"
}