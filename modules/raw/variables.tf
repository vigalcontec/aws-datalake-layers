# =============================================================================
# Raw Layer - Variables
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
variable "transition_to_ia_days" {
  description = "Days before transitioning objects to STANDARD_IA"
  type        = number
  default     = 90
}

variable "transition_to_glacier_days" {
  description = "Days before transitioning objects to GLACIER"
  type        = number
  default     = 180
}

variable "noncurrent_version_expiration_days" {
  description = "Days before expiring noncurrent object versions"
  type        = number
  default     = 90
}
