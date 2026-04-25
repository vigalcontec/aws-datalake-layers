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

resource "aws_s3_bucket_policy" "staging" {
  bucket = aws_s3_bucket.staging.id

  depends_on = [aws_s3_bucket_public_access_block.staging]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.staging.arn,
          "${aws_s3_bucket.staging.arn}/*"
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
          aws_s3_bucket.staging.arn,
          "${aws_s3_bucket.staging.arn}/*"
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
# Access Logging (Optional)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_logging" "staging" {
  count = var.enable_access_logging ? 1 : 0

  bucket        = aws_s3_bucket.staging.id
  target_bucket = var.logs_bucket_name
  target_prefix = "staging/${var.environment}/"
}

# -----------------------------------------------------------------------------
# KMS Key - Staging Layer Encryption
# -----------------------------------------------------------------------------
resource "aws_kms_key" "staging" {
  description             = "KMS key for Staging layer data encryption - ${var.environment}"
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
    Name        = "datalake-staging-kms-${var.environment}"
    Project     = "datalake"
    Layer       = "staging"
    Environment = var.environment
  })
}

resource "aws_kms_alias" "staging" {
  name          = "alias/datalake-staging-${var.environment}"
  target_key_id = aws_kms_key.staging.key_id
}

# -----------------------------------------------------------------------------
# SSM Parameter Store - Cross-project exports
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "bucket_arn" {
  name        = "/${var.environment}/datalake/staging/bucket_arn"
  description = "ARN of the Staging layer S3 bucket"
  type        = "String"
  value       = aws_s3_bucket.staging.arn

  tags = merge(var.tags, {
    Name        = "datalake-staging-bucket-arn-${var.environment}"
    Project     = "datalake"
    Layer       = "staging"
    Environment = var.environment
  })
}

resource "aws_ssm_parameter" "bucket_name" {
  name        = "/${var.environment}/datalake/staging/bucket_name"
  description = "Name of the Staging layer S3 bucket"
  type        = "String"
  value       = aws_s3_bucket.staging.id

  tags = merge(var.tags, {
    Name        = "datalake-staging-bucket-name-${var.environment}"
    Project     = "datalake"
    Layer       = "staging"
    Environment = var.environment
  })
}

resource "aws_ssm_parameter" "kms_key_arn" {
  name        = "/${var.environment}/datalake/staging/kms_key_arn"
  description = "ARN of the Staging layer KMS key"
  type        = "String"
  value       = aws_kms_key.staging.arn

  tags = merge(var.tags, {
    Name        = "datalake-staging-kms-arn-${var.environment}"
    Project     = "datalake"
    Layer       = "staging"
    Environment = var.environment
  })
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
