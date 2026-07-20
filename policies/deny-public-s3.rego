package terraform

import rego.v1

#
# Policy 1: deny-public-s3
# Ensure document storage can never become publicly accessible.
# Enforced guardrails:
# 1. Public Access Block must be fully enabled.
# 2. Public ACLs are forbidden.


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
        "deny-public-s3: %s must have %s=true. Public access protection cannot be relaxed.",
        [resource.address, setting],
    )
}

deny contains msg if {
    some resource in input.terraform_plan.resource_changes

    resource.type == "aws_s3_bucket_acl"

    acl := resource.change.after.acl

    acl in {
        "public-read",
        "public-read-write",
        "authenticated-read",
    }

    msg := sprintf(
        "deny-public-s3: %s uses forbidden ACL '%s'. Document buckets must remain private.",
        [resource.address, acl],
    )
}