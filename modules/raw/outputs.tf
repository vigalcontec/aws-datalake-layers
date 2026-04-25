# =============================================================================
# Raw Layer - Outputs
# =============================================================================

output "bucket_id" {
  description = "Raw layer S3 bucket ID"
  value       = aws_s3_bucket.raw.id
}

output "bucket_arn" {
  description = "Raw layer S3 bucket ARN"
  value       = aws_s3_bucket.raw.arn
}

output "bucket_domain_name" {
  description = "Raw layer S3 bucket domain name"
  value       = aws_s3_bucket.raw.bucket_domain_name
}

output "kms_key_id" {
  description = "KMS key ID for raw layer encryption"
  value       = aws_kms_key.raw.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for raw layer encryption"
  value       = aws_kms_key.raw.arn
}
