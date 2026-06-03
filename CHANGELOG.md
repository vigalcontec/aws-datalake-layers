# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-06-03

### Added

- **EventBridge Notifications** - S3 events now sent to EventBridge for event-driven architectures
  - Raw layer: `aws_s3_bucket_notification.raw` with `eventbridge = true`
  - Staging layer: `aws_s3_bucket_notification.staging` with `eventbridge = true`
  - Enables Step Functions and other services to react to S3 object events

---

## [0.3.0] - 2026-04-25

### Added

- **S3 Bucket Policies** - TLS 1.2+ enforcement on all buckets
  - `EnforceTLSRequestsOnly` - Denies non-HTTPS requests
  - `EnforceTLSVersion` - Denies TLS versions below 1.2

- **Access Logging (Optional)** - Prepared for future compliance (GDPR, SOC2, HIPAA)
  - `enable_access_logging` - Boolean, default `false`
  - `logs_bucket_name` - Target bucket for access logs
  - Log prefix format: `{layer}/{environment}/`

- **KMS Key Policy** - Explicit policy for AWS service principals
  - `AllowLambdaService` - Lambda functions can decrypt/encrypt data
  - `AllowGlueService` - Glue jobs can decrypt/encrypt data
  - `AllowServiceRolesViaGrants` - AWS services can create grants
  - All statements scoped to same account via `kms:CallerAccount` condition

### Changed

- **Lifecycle Configuration** - Now uses variables instead of hardcoded values
  - Raw: `var.transition_to_ia_days`, `var.transition_to_glacier_days`, `var.noncurrent_version_expiration_days`
  - Business: `var.archive_to_glacier_days`

- **GitHub Workflow** - Refactored from 358 lines to 224 lines using matrix strategy
  - Parallel validation across all modules
  - Dynamic layer matrix for selective deployment
  - `max-parallel: 1` ensures sequential layer deployment
  - Cleaner job structure with section comments

### Security

- ✅ TLS 1.2+ enforced via bucket policy (not just encryption)
- ✅ Proper `depends_on` for bucket policy after public access block

---

## [0.2.0] - 2026-04-25

### Added

- **SSM Parameter Store exports** - All layers now export bucket ARNs, names, and KMS key ARNs to SSM for cross-project integration

### SSM Parameters Created

| Layer | Parameter Path | Value |
|-------|----------------|-------|
| Raw | `/{env}/datalake/raw/bucket_arn` | S3 bucket ARN |
| Raw | `/{env}/datalake/raw/bucket_name` | S3 bucket name |
| Raw | `/{env}/datalake/raw/kms_key_arn` | KMS key ARN |
| Staging | `/{env}/datalake/staging/bucket_arn` | S3 bucket ARN |
| Staging | `/{env}/datalake/staging/bucket_name` | S3 bucket name |
| Staging | `/{env}/datalake/staging/kms_key_arn` | KMS key ARN |
| Business | `/{env}/datalake/business/bucket_arn` | S3 bucket ARN |
| Business | `/{env}/datalake/business/bucket_name` | S3 bucket name |
| Business | `/{env}/datalake/business/kms_key_arn` | KMS key ARN |

### Changed

- **KMS keys** - Added `Project = "datalake"` tag for IAM policy condition matching

---

## [0.1.0] - 2026-04-25

### Initial Release

Data lake foundation infrastructure for AWS with three-layer architecture.

### Added

- **Project structure**:
  - `modules/raw/` - Raw layer S3 bucket for ingested data
  - `modules/staging/` - Staging layer for transformed/cleaned data
  - `modules/business/` - Business layer for analytics-ready data

- **Raw Layer** (`modules/raw/`):
  - S3 bucket with versioning and lifecycle policies
  - KMS encryption for data at rest
  - Cross-account access policies (optional)
  - Event notifications for data ingestion triggers

- **Staging Layer** (`modules/staging/`):
  - S3 bucket for intermediate transformations
  - Glue Catalog database and tables (optional)
  - Lifecycle policies for temporary data cleanup

- **Business Layer** (`modules/business/`):
  - S3 bucket for curated, analytics-ready data
  - Athena workgroup configuration (optional)
  - IAM policies for data consumers

- **Shared Components**:
  - Common tagging strategy
  - Cross-layer IAM policies
  - S3 bucket policies enforcing TLS 1.2+

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Data Lake Layers                        │
├─────────────────┬─────────────────┬─────────────────────────┤
│   Raw Layer     │  Staging Layer  │    Business Layer       │
│                 │                 │                         │
│ • Ingested data │ • Cleaned data  │ • Analytics-ready       │
│ • Immutable     │ • Transformed   │ • Aggregated            │
│ • Partitioned   │ • Validated     │ • Optimized (Parquet)   │
└─────────────────┴─────────────────┴─────────────────────────┘
```

### Security

- ✅ KMS encryption for all S3 buckets
- ✅ S3 bucket policies enforce TLS 1.2+
- ✅ Public access blocked on all buckets
- ✅ Versioning enabled for data recovery
- ✅ Cross-layer access controlled via IAM

### Dependencies

- Requires `aws-bootstrap-tfstate-oidc` for:
  - Terraform state backend (S3 + KMS)
  - GitHub OIDC authentication
  - IAM role for CI/CD deployments
