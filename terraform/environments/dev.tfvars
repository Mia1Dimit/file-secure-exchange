applicationname = "file-secure-exchange"
applicationid   = "004"
environment     = "dev"

# ─── IAM Roles ───────────────────────────────────────────────────────────────
# lambda_execution: used by all Lambda functions (presign broker, AI classifier)
iam_roles = {
  lambda_execution = {
    name               = "fse-lambda-execution-dev"
    assume_role_policy = "lambda-assume-role-policy.json"
    specifictags = {
      Purpose = "Lambda execution for presign broker and AI classifier"
    }
    policies = {
      lambda_exec = {
        name   = "fse-lambda-execution-policy-dev"
        policy = "lambda-execution-policy.json"
      }
    }
    managed_policies = {}
  }
}

# ─── S3 Buckets ──────────────────────────────────────────────────────────────
# Private, versioned document store — presigned URLs only, all public access
# blocked. SSE-S3 default encryption applied by AWS. Notifications are wired
# in Phase 2 once the Lambda functions are deployed.
s3s = {
  documents = {
    name                  = "fse-documents-dev"
    blockpublicacls       = true
    blockpublicpolicy     = true
    ignorepublicacls      = true
    restrictpublicbuckets = true
    environment           = "dev"
    enable_versioning     = "Enabled"
    rules                 = {}
    notifications = {
      lambda_events = {
        lambda_function = []
      }
    }
    replication_role  = null
    replication_rules = []
    specifictags = {
      Purpose = "Private document storage for secure exchange"
    }
  }
}

# ─── DynamoDB Tables ─────────────────────────────────────────────────────────
# documents  : document registry — one record per uploaded file
# access_log : immutable audit log — one record per access event
dynamodb_tables = {
  documents = {
    table_name   = "fse-documents-dev"
    hash_key     = "document_id"
    billing_mode = "PAY_PER_REQUEST"
    global_secondary_indexes = [
      {
        name            = "owner-index"
        hash_key        = "owner_id"
        projection_type = "ALL"
      }
    ]
    enable_point_in_time_recovery = false
    ttl_attribute_name            = "expires_at"
  }
  access_log = {
    table_name   = "fse-access-log-dev"
    hash_key     = "event_id"
    billing_mode = "PAY_PER_REQUEST"
    global_secondary_indexes = [
      {
        name            = "document-index"
        hash_key        = "document_id"
        projection_type = "ALL"
      }
    ]
    enable_point_in_time_recovery = true
    ttl_attribute_name            = null
  }
}

# ─── Cognito User Pools ───────────────────────────────────────────────────────
# Single pool with sender and receiver groups managed post-apply via
# aws_cognito_user_group (outside Terraform scope for MVP).
cognito_user_pools = {
  main = {
    pool_name            = "fse-user-pool-dev"
    app_client_name      = "fse-app-client-dev"
    domain_prefix        = "fse-dev"
    callback_urls        = ["https://localhost:3000/callback"]
    logout_urls          = ["https://localhost:3000/logout"]
    allowed_oauth_flows  = ["code"]
    allowed_oauth_scopes = ["email", "openid", "profile"]
    specifictags = {
      Purpose = "User authentication for sender and receiver identities"
    }
  }
}

# ─── Lambda Functions (Phase 2) ───────────────────────────────────────────────
lambda_functions = {
  presign_broker = {
    name        = "fse-presign-broker-dev"
    handler     = "index.handler"
    runtime     = "python3.12"
    timeout     = 10
    memory_size = 128
    source_dir  = "../../lambdas/presign-handler"
    output_path = "/tmp/lambda-builds/presign-handler.zip"
    vpc_config  = null
    environment_variables = {
      DOCUMENTS_TABLE        = "fse-documents-dev"
      ACCESS_LOG_TABLE       = "fse-access-log-dev"
      DOCUMENTS_BUCKET       = "fse-documents-dev"
      PRESIGN_EXPIRY_SECONDS = "300"
    }
  }
}

# ─── Lambda Permissions (Phase 2) ────────────────────────────────────────────
lambda_permissions = {}

# ─── EventBridge Schedulers (Phase 2) ────────────────────────────────────────
eventbridge_schedulers = {}

# ─── KMS Keys (Phase 4 — CMK hardening, see ADR-0003) ────────────────────────
kms_keys = {}

# ─── WAF Web ACLs (Phase 4 — edge protection) ────────────────────────────────
waf_web_acls = {}
