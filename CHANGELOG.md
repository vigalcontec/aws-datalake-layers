# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
