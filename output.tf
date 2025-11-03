output "vpc_id" {
  description = "VPC ID."
  value       = local.vpc_id
}

output "subnets_ids" {
  description = "Subnets ID."
  value       = local.subnet_ids
}

output "security_group_id" {
  description = "Security groups ID."
  value       = local.security_group_id
}

output "kms_policy_documents_json" {
  description = "KMS policy documents to add to the policy of the key specified via var.kms_key_id."
  value       = module.kms_key.policy_documents_json
}

output "kms_policy_dependency" {
  description = "To use with 'depends_on' for resources requiring that KMS policy is updated before creation. Only if var.kms_key_id is set."
  value       = module.kms_key.policy_dependency
}

output "kms_key_id" {
  description = "KMS key ID."
  value       = module.kms_key.id
}

output "kms_key_arn" {
  description = "KMS key ARN."
  value       = module.kms_key.arn
}

output "ipv6_enabled" {
  description = "Whether IPv6 is enabled on the VPC."
  value       = local.vpc_enabled
}

output "public_subnets_ids" {
  description = "Public subnets IDs. Empty list if public subnets are not enabled."
  value       = local.public_subnets_enabled ? [for az in local.vpc_availability_zones : aws_subnet.public[az].id] : []
}
