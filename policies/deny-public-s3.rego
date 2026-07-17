package terraform

import rego.v1

# Policy 1: Deny Public S3

# Reasoning: document exchange systems fail catastrophically when storage is
# even accidentally public. No public ACLs, no public bucket policies, and
# Block Public Access must be fully enabled on every bucket.

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type == "aws_s3_bucket_public_access_block"
	change := resource.change.after

	some setting in [
		"block_public_acls",
		"block_public_policy",
		"ignore_public_acls",
		"restrict_public_buckets",
	]
	change[setting] == false

	msg := sprintf(
		"deny-public-s3: %s must have %s=true — public access block cannot be relaxed on any document bucket",
		[resource.address, setting],
	)
}

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type == "aws_s3_bucket_acl"
	acl := resource.change.after.acl
	acl in ["public-read", "public-read-write", "authenticated-read"]

	msg := sprintf(
		"deny-public-s3: %s uses ACL '%s' — document buckets must never be publicly or authenticated-readable",
		[resource.address, acl],
	)
}

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type == "aws_s3_bucket"
	not has_public_access_block(resource.address)

	msg := sprintf(
		"deny-public-s3: %s has no aws_s3_bucket_public_access_block resource attached — every document bucket must explicitly block public access",
		[resource.address],
	)
}

deny contains msg if {
	some resource in input.terraform_plan.resource_changes
	resource.type == "aws_s3_bucket"
	not has_public_access_block(resource)

	msg := sprintf(
		"deny-public-s3: %s has no aws_s3_bucket_public_access_block resource attached — every document bucket must explicitly block public access",
		[resource.address],
	)
}