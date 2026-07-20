package terraform

import rego.v1

deny contains msg if {
    some bucket in input.terraform_plan.resource_changes

    bucket.type == "aws_s3_bucket"

    not some policy in input.terraform_plan.resource_changes {
        policy.type == "aws_s3_bucket_policy"

        doc := json.unmarshal(policy.change.after.policy)

        some stmt in doc.Statement

        stmt.Effect == "Deny"

        stmt.Condition.Bool["aws:SecureTransport"] == "false"
    }

    msg := sprintf(
        "require-tls: %s has no bucket policy denying non-TLS requests",
        [bucket.address],
    )
}