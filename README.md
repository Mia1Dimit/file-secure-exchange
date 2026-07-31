# File Secure Exchange

File Secure Exchange is an AWS-based, security-first document exchange platform for sensitive files (referrals, invoices, prescriptions, and related records).

It provides short-lived presigned upload/download URLs, enforces role-based access with Cognito JWTs, and writes immutable access logs for every request.

## What This Project Does

- Issues presigned S3 upload URLs for approved sender users.
- Issues presigned S3 download URLs for approved receiver users.
- Stores document metadata in DynamoDB.
- Stores access/audit events in a separate DynamoDB table.
- Deploys infrastructure via reusable Terraform modules.
- Applies policy-as-code checks (OPA/Rego) in CI to prevent insecure infrastructure changes.

## Architecture (MVP)

- API: API Gateway HTTP API (JWT authorizer)
- Auth: Amazon Cognito (sender/receiver groups)
- Compute: AWS Lambda (`presign-handler`)
- Storage: Private S3 bucket (versioned, encrypted, no public access)
- Metadata: DynamoDB (`documents` table)
- Audit: DynamoDB (`access_log` table)
- IaC: Terraform modules + environment tfvars

## Repository Structure

```text
file-secure-exchange/
├── lambdas/presign-handler/     # Presign and access broker Lambda
├── terraform/
│   ├── infra/                   # Root infra wiring
│   ├── modules/                 # Reusable Terraform modules
│   └── environments/dev.tfvars  # Dev environment values
├── policies/                    # OPA/Rego policy checks
├── ADVANCED_PLAN.md             # Detailed architecture/delivery plan
└── status.md                    # Current implementation status
```

## Quick Start

### 1) Prerequisites

- Terraform 1.5+
- AWS CLI configured with credentials
- Python 3.12 (for Lambda runtime parity)

### 2) Configure Backend + Variables

Set backend settings and environment values in:

- `terraform/infra/backend.tf`
- `terraform/environments/dev.tfvars`

### 3) Deploy Infrastructure

```bash
cd terraform/infra
terraform init
terraform plan -var-file=../environments/dev.tfvars
terraform apply -var-file=../environments/dev.tfvars
```

## API Endpoints

The `presign-handler` Lambda serves two protected routes:

- `POST /documents` -> create metadata + return presigned upload URL
- `GET /documents/{document_id}/download` -> validate access + return presigned download URL

Authentication is via Cognito JWT claims from API Gateway authorizer context.

## Security Baseline

- S3 block public access enabled
- S3 server-side encryption enabled
- TLS-only bucket policy enforcement
- IAM wildcard restrictions enforced by policy checks
- Mandatory tagging policy enforced in CI

See `policies/` for Rego rules used in plan-time governance.

## Current Status

Phase 1 foundations and the presign broker flow are implemented. Refer to `status.md` for the latest progress and next steps.

## Roadmap

- Phase 2: Event-driven document classification and review routing
- Phase 3+: Hardening enhancements (KMS CMK, WAF, broader controls)

## Notes

This repository is intentionally organized to keep the upload/download path simple, auditable, and secure by default.