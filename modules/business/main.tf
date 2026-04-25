# =============================================================================
# Business Layer - Data Lake
#
# Consumption layer for analytics-ready, curated data.
# Data is optimized for querying and business intelligence.
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
# S3 Bucket - Business Data
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "business" {
  bucket = "datalake-business-${var.company_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name        = "datalake-business-${var.environment}"
    Layer       = "business"
    DataClass   = "curated"
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "business" {
  bucket = aws_s3_bucket.business.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "business" {
  bucket = aws_s3_bucket.business.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.business.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "business" {
  bucket = aws_s3_bucket.business.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "business" {
  bucket = aws_s3_bucket.business.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    transition {
      days          = 365
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
# KMS Key - Business Layer Encryption
# -----------------------------------------------------------------------------
resource "aws_kms_key" "business" {
  description             = "KMS key for Business layer data encryption - ${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(var.tags, {
    Name        = "datalake-business-kms-${var.environment}"
    Project     = "datalake"
    Layer       = "business"
    Environment = var.environment
  })
}

resource "aws_kms_alias" "business" {
  name          = "alias/datalake-business-${var.environment}"
  target_key_id = aws_kms_key.business.key_id
}

# -----------------------------------------------------------------------------
# SSM Parameter Store - Cross-project exports
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "bucket_arn" {
  name        = "/${var.environment}/datalake/business/bucket_arn"
  description = "ARN of the Business layer S3 bucket"
  type        = "String"
  value       = aws_s3_bucket.business.arn

  tags = merge(var.tags, {
    Name        = "datalake-business-bucket-arn-${var.environment}"
    Project     = "datalake"
    Layer       = "business"
    Environment = var.environment
  })
}

resource "aws_ssm_parameter" "bucket_name" {
  name        = "/${var.environment}/datalake/business/bucket_name"
  description = "Name of the Business layer S3 bucket"
  type        = "String"
  value       = aws_s3_bucket.business.id

  tags = merge(var.tags, {
    Name        = "datalake-business-bucket-name-${var.environment}"
    Project     = "datalake"
    Layer       = "business"
    Environment = var.environment
  })
}

resource "aws_ssm_parameter" "kms_key_arn" {
  name        = "/${var.environment}/datalake/business/kms_key_arn"
  description = "ARN of the Business layer KMS key"
  type        = "String"
  value       = aws_kms_key.business.arn

  tags = merge(var.tags, {
    Name        = "datalake-business-kms-arn-${var.environment}"
    Project     = "datalake"
    Layer       = "business"
    Environment = var.environment
  })
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
