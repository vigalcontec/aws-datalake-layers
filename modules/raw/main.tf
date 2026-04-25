# =============================================================================
# Raw Layer - Data Lake
#
# Ingestion layer for raw, immutable data from various sources.
# Data is stored in its original format with minimal transformation.
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
# S3 Bucket - Raw Data
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "raw" {
  bucket = "datalake-raw-${var.company_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name        = "datalake-raw-${var.environment}"
    Layer       = "raw"
    DataClass   = "raw"
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.raw.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------------------------------------------------------
# KMS Key - Raw Layer Encryption
# -----------------------------------------------------------------------------
resource "aws_kms_key" "raw" {
  description             = "KMS key for Raw layer data encryption - ${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(var.tags, {
    Name        = "datalake-raw-kms-${var.environment}"
    Layer       = "raw"
    Environment = var.environment
  })
}

resource "aws_kms_alias" "raw" {
  name          = "alias/datalake-raw-${var.environment}"
  target_key_id = aws_kms_key.raw.key_id
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
