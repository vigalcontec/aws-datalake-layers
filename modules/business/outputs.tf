# =============================================================================
# Business Layer - Outputs
# =============================================================================

output "bucket_id" {
  description = "Business layer S3 bucket ID"
  value       = aws_s3_bucket.business.id
}

output "bucket_arn" {
  description = "Business layer S3 bucket ARN"
  value       = aws_s3_bucket.business.arn
}

output "bucket_domain_name" {
  description = "Business layer S3 bucket domain name"
  value       = aws_s3_bucket.business.bucket_domain_name
}

output "kms_key_id" {
  description = "KMS key ID for business layer encryption"
  value       = aws_kms_key.business.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for business layer encryption"
  value       = aws_kms_key.business.arn
}
