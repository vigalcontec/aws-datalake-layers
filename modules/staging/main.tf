# =============================================================================
# Staging Layer - Data Lake
#
# Transformation layer for cleaned and validated data.
# Data is processed from raw layer and prepared for business consumption.
# =============================================================================

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket - Staging Data
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "staging" {
  bucket = "datalake-staging-${var.company_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name        = "datalake-staging-${var.environment}"
    Layer       = "staging"
    DataClass   = "processed"
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "staging" {
  bucket = aws_s3_bucket.staging.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.staging.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket = aws_s3_bucket.staging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    id     = "cleanup-temporary-data"
    status = "Enabled"

    expiration {
      days = var.staging_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------------------------------------------------------
# KMS Key - Staging Layer Encryption
# -----------------------------------------------------------------------------
resource "aws_kms_key" "staging" {
  description             = "KMS key for Staging layer data encryption - ${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(var.tags, {
    Name        = "datalake-staging-kms-${var.environment}"
    Layer       = "staging"
    Environment = var.environment
  })
}

resource "aws_kms_alias" "staging" {
  name          = "alias/datalake-staging-${var.environment}"
  target_key_id = aws_kms_key.staging.key_id
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
