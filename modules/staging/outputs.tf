# =============================================================================
# Staging Layer - Outputs
# =============================================================================

output "bucket_id" {
  description = "Staging layer S3 bucket ID"
  value       = aws_s3_bucket.staging.id
}

output "bucket_arn" {
  description = "Staging layer S3 bucket ARN"
  value       = aws_s3_bucket.staging.arn
}

output "bucket_domain_name" {
  description = "Staging layer S3 bucket domain name"
  value       = aws_s3_bucket.staging.bucket_domain_name
}

output "kms_key_id" {
  description = "KMS key ID for staging layer encryption"
  value       = aws_kms_key.staging.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for staging layer encryption"
  value       = aws_kms_key.staging.arn
}
