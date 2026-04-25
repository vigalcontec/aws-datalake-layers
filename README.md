# AWS Data Lake Layers

[![Terraform](https://img.shields.io/badge/Terraform-1.10%2B-7B42BC?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-S3%20%7C%20KMS-FF9900?logo=amazon-aws)](https://aws.amazon.com/)

Data lake foundation with Raw, Staging, and Business layers. Includes S3 bucket configurations, lifecycle policies, and cross-layer access controls for data engineering pipelines.

---

## 📋 Table of Contents

- [Architecture](#architecture)
- [Data Formats by Layer](#data-formats-by-layer)
- [Data Flow Example](#data-flow-example)
- [Lifecycle Policy](#lifecycle-policy)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Module Reference](#module-reference)
- [Security](#security)
- [Dependencies](#dependencies)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Data Lake Architecture                            │
├─────────────────────┬─────────────────────┬─────────────────────────────────┤
│     Raw Layer       │   Staging Layer     │       Business Layer            │
│                     │                     │                                 │
│ • Ingested data     │ • Cleaned data      │ • Analytics-ready               │
│ • Immutable         │ • Transformed       │ • Aggregated                    │
│ • Original format   │ • Validated         │ • Optimized (Parquet/ORC)       │
│ • Partitioned       │ • Temporary         │ • Query-optimized               │
│                     │                     │                                 │
│ Retention: Archive  │ Retention: 30 days  │ Retention: Long-term            │
│ → IA (90d)          │ (configurable)      │ → Glacier (365d)                │
│ → Glacier (180d)    │                     │                                 │
└─────────────────────┴─────────────────────┴─────────────────────────────────┘
```

---

## Data Formats by Layer

### Raw Layer - Original Files

The Raw Layer stores data in its **original format**, exactly as received:

| File Type | Examples | Stored As |
|-----------|----------|-----------|
| Documents | Invoices, contracts, reports | `.pdf` |
| Images | Photos, scans, screenshots | `.jpg`, `.png`, `.tiff` |
| Web content | Web scrapes, emails | `.html` |
| Tabular | Exports from systems | `.csv`, `.xlsx` |
| Structured | API responses | `.json`, `.xml` |

**Key principle:** Raw layer is **immutable** - never modify the original files.

### Staging Layer - Transformed Data

The Staging Layer holds **processed/extracted** data. JSON is ideal for this layer:

| Source (Raw) | Transformation | Output (Staging) |
|--------------|----------------|------------------|
| PDF invoice | OCR + extraction | `invoice.json` with structured fields |
| Image | ML classification | `metadata.json` with labels, tags |
| HTML page | Parsing/scraping | `content.json` with extracted data |
| CSV files | Cleaning, validation | `cleaned.json` or `cleaned.parquet` |

### Business Layer - Analytics-Ready

The Business Layer contains **aggregated, query-optimized** data:

| Format | Use Case |
|--------|----------|
| Parquet | Columnar format, best for Athena/Spark queries |
| ORC | Alternative columnar format |
| Delta Lake | Versioned tables with ACID transactions |

### Recommended Formats Summary

| Layer | Best Formats | Why |
|-------|--------------|-----|
| **Raw** | Original (PDF, JPG, HTML, CSV, JSON) | Preserve source data |
| **Staging** | JSON, Parquet, CSV | Structured, easy to process |
| **Business** | Parquet, ORC | Columnar, optimized for analytics |

---

## Data Flow Example

```
Raw Layer                    Staging Layer                Business Layer
─────────────────────────────────────────────────────────────────────────
invoice_001.pdf    →    invoice_001.json           →    invoices.parquet
                        {                                (aggregated,
                          "vendor": "Acme",              query-optimized)
                          "amount": 1500.00,
                          "date": "2026-04-25"
                        }

product_photo.jpg  →    product_photo_meta.json    →    product_catalog.parquet
                        {
                          "labels": ["electronics"],
                          "colors": ["black", "silver"]
                        }

web_page.html      →    extracted_content.json     →    web_analytics.parquet
                        {
                          "title": "Product Page",
                          "price": 299.99,
                          "category": "Electronics"
                        }
```

---

## Lifecycle Policy

S3 Lifecycle transitions are based on **days after object creation**, not last access:

| Layer | Transition | Days After Creation |
|-------|------------|---------------------|
| **Raw** | → STANDARD_IA | 90 days |
| **Raw** | → GLACIER | 180 days |
| **Staging** | → DELETED | 30 days (configurable) |
| **Business** | → GLACIER | 365 days |

> **Note:** If you need access-based transitions, consider using **S3 Intelligent-Tiering** instead.

---

## Repository Structure

```
aws-datalake-layers/
├── modules/
│   ├── raw/                    # Raw layer module
│   │   ├── main.tf            # S3 bucket, KMS key
│   │   ├── variables.tf       # Input variables
│   │   └── outputs.tf         # Module outputs
│   │
│   ├── staging/               # Staging layer module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── business/              # Business layer module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── CHANGELOG.md
└── README.md
```

---

## Prerequisites

- **Terraform** >= 1.10.0
- **AWS CLI** configured with appropriate credentials
- **aws-bootstrap-tfstate-oidc** deployed (for state backend and OIDC)

---

## Quick Start

### 1. Deploy Raw Layer

```hcl
module "raw_layer" {
  source = "./modules/raw"

  environment  = "dev"
  company_name = "yourcompany"
  aws_region   = "eu-west-1"

  tags = {
    Project     = "datalake"
    Environment = "dev"
  }
}
```

### 2. Deploy All Layers

```hcl
module "raw" {
  source       = "./modules/raw"
  environment  = var.environment
  company_name = var.company_name
  tags         = var.tags
}

module "staging" {
  source       = "./modules/staging"
  environment  = var.environment
  company_name = var.company_name
  tags         = var.tags
}

module "business" {
  source       = "./modules/business"
  environment  = var.environment
  company_name = var.company_name
  tags         = var.tags
}
```

---

## Module Reference

### Raw Layer

| Resource | Name Pattern | Purpose |
|----------|--------------|---------|
| S3 Bucket | `datalake-raw-{company}-{env}-{account}` | Raw data storage |
| KMS Key | `datalake-raw-kms-{env}` | Encryption at rest |

**Lifecycle:**
- 90 days → STANDARD_IA
- 180 days → GLACIER
- Noncurrent versions expire after 90 days

### Staging Layer

| Resource | Name Pattern | Purpose |
|----------|--------------|---------|
| S3 Bucket | `datalake-staging-{company}-{env}-{account}` | Transformed data |
| KMS Key | `datalake-staging-kms-{env}` | Encryption at rest |

**Lifecycle:**
- Data expires after 30 days (configurable)
- Noncurrent versions expire after 30 days

### Business Layer

| Resource | Name Pattern | Purpose |
|----------|--------------|---------|
| S3 Bucket | `datalake-business-{company}-{env}-{account}` | Curated data |
| KMS Key | `datalake-business-kms-{env}` | Encryption at rest |

**Lifecycle:**
- 365 days → GLACIER
- Noncurrent versions expire after 90 days

---

## Security

- ✅ KMS encryption for all S3 buckets (automatic key rotation)
- ✅ S3 bucket policies enforce TLS 1.2+
- ✅ Public access blocked on all buckets
- ✅ Versioning enabled for data recovery
- ✅ Bucket key enabled for cost optimization

---

## Dependencies

This module depends on:

- **aws-bootstrap-tfstate-oidc** - Provides:
  - Terraform state backend (S3 + KMS)
  - GitHub OIDC authentication for CI/CD
  - IAM role for deployments
