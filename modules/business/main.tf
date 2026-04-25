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

resource "aws_s3_bucket_policy" "business" {
  bucket = aws_s3_bucket.business.id

  depends_on = [aws_s3_bucket_public_access_block.business]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.business.arn,
          "${aws_s3_bucket.business.arn}/*"
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
          aws_s3_bucket.business.arn,
          "${aws_s3_bucket.business.arn}/*"
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

resource "aws_s3_bucket_lifecycle_configuration" "business" {
  bucket = aws_s3_bucket.business.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    transition {
      days          = var.archive_to_glacier_days
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
# Access Logging (Optional)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_logging" "business" {
  count = var.enable_access_logging ? 1 : 0

  bucket        = aws_s3_bucket.business.id
  target_bucket = var.logs_bucket_name
  target_prefix = "business/${var.environment}/"
}

# -----------------------------------------------------------------------------
# KMS Key - Business Layer Encryption
# -----------------------------------------------------------------------------
resource "aws_kms_key" "business" {
  description             = "KMS key for Business layer data encryption - ${var.environment}"
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
