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

# -----------------------------------------------------------------------------
# EventBridge Notifications - Enable S3 events to EventBridge
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_notification" "raw" {
  bucket      = aws_s3_bucket.raw.id
  eventbridge = true
}

resource "aws_s3_bucket_policy" "raw" {
  bucket = aws_s3_bucket.raw.id

  depends_on = [aws_s3_bucket_public_access_block.raw]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "EnforceTLSVersion"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*"
        ]
        Condition = {
          NumericLessThan = {
            "s3:TlsVersion" = "1.2"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = var.transition_to_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.transition_to_glacier_days
      storage_class = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------------------------------------------------------
# Access Logging (Optional)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_logging" "raw" {
  count = var.enable_access_logging ? 1 : 0

  bucket        = aws_s3_bucket.raw.id
  target_bucket = var.logs_bucket_name
  target_prefix = "raw/${var.environment}/"
}

# -----------------------------------------------------------------------------
# KMS Key - Raw Layer Encryption
# -----------------------------------------------------------------------------
resource "aws_kms_key" "raw" {
  description             = "KMS key for Raw layer data encryption - ${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowLambdaService"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "AllowGlueService"
        Effect    = "Allow"
        Principal = { Service = "glue.amazonaws.com" }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "AllowServiceRolesViaGrants"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "datalake-raw-kms-${var.environment}"
    Project     = "datalake"
    Layer       = "raw"
    Environment = var.environment
  })
}

resource "aws_kms_alias" "raw" {
  name          = "alias/datalake-raw-${var.environment}"
  target_key_id = aws_kms_key.raw.key_id
}

# -----------------------------------------------------------------------------
# SSM Parameter Store - Cross-project exports
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "bucket_arn" {
  name        = "/${var.environment}/datalake/raw/bucket_arn"
  description = "ARN of the Raw layer S3 bucket"
  type        = "String"
  value       = aws_s3_bucket.raw.arn

  tags = merge(var.tags, {
    Name        = "datalake-raw-bucket-arn-${var.environment}"
    Project     = "datalake"
    Layer       = "raw"
    Environment = var.environment
  })
}

resource "aws_ssm_parameter" "bucket_name" {
  name        = "/${var.environment}/datalake/raw/bucket_name"
  description = "Name of the Raw layer S3 bucket"
  type        = "String"
  value       = aws_s3_bucket.raw.id

  tags = merge(var.tags, {
    Name        = "datalake-raw-bucket-name-${var.environment}"
    Project     = "datalake"
    Layer       = "raw"
    Environment = var.environment
  })
}

resource "aws_ssm_parameter" "kms_key_arn" {
  name        = "/${var.environment}/datalake/raw/kms_key_arn"
  description = "ARN of the Raw layer KMS key"
  type        = "String"
  value       = aws_kms_key.raw.arn

  tags = merge(var.tags, {
    Name        = "datalake-raw-kms-arn-${var.environment}"
    Project     = "datalake"
    Layer       = "raw"
    Environment = var.environment
  })
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
