# =============================================================================
# Business Layer - Variables
# =============================================================================

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be dev, qa, or prod."
  }
}

variable "company_name" {
  description = "Company name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-1"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Lifecycle Configuration
# -----------------------------------------------------------------------------
variable "archive_to_glacier_days" {
  description = "Days before archiving business data to GLACIER"
  type        = number
  default     = 365
}

# -----------------------------------------------------------------------------
# Access Logging (Optional - for future compliance requirements)
# -----------------------------------------------------------------------------
variable "enable_access_logging" {
  description = "Enable S3 access logging for audit trail. Requires logs_bucket_name when true."
  type        = bool
  default     = false
}

variable "logs_bucket_name" {
  description = "Name of the S3 bucket for access logs. Required if enable_access_logging is true."
  type        = string
  default     = ""
}
