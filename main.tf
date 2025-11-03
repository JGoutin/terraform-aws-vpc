/*
Network configuration
*/

locals {
  region             = data.aws_region.current.name
  vpc_enabled        = length(var.subnets_ids) == 0
  vpc_resource_count = local.vpc_enabled ? 1 : 0
  vpc_availability_zones = toset(
    local.vpc_enabled ? (
      var.availability_zones_count != null ?
      slice(sort(data.aws_availability_zones.available[0].names), 0, var.availability_zones_count) :
      data.aws_availability_zones.available[0].names
    )
  : [])

  # AWS services requirements
  vpce_gateway_services_all = ["s3", "dynamodb"]
  vpce_gateway_services     = setintersection(var.vpc_endpoints_services, local.vpce_gateway_services_all)
  vpce_interfaces_services  = setsubtract(var.vpc_endpoints_services, local.vpce_gateway_services_all)
  vpce_interfaces_required  = length(local.vpce_interfaces_services) > 0

  # Network egress access
  internet_required       = var.internet_access_allowed || (local.vpce_interfaces_required && !var.vpc_endpoints_allowed)
  vpce_interfaces_enabled = local.vpce_interfaces_required && var.vpc_endpoints_allowed && !local.internet_required && local.vpc_enabled
  nat_gateways_enabled    = local.internet_required && var.nat_gateways_allowed && local.vpc_enabled
  public_subnet_enabled   = local.internet_required && !var.nat_gateways_allowed && local.vpc_enabled
}

data "aws_availability_zones" "available" {
  count = local.vpc_resource_count
  state = "available"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}


/*
KMS key
*/

module "kms_key" {
  source  = "JGoutin/kms-key/aws"
  version = "~> 1.0"

  id                = var.kms_key_id
  name_prefix       = var.name_prefix
  policy_dependency = var.kms_policy_dependency
  policy_documents_json = local.vpc_flow_log_enabled ? [
    data.aws_iam_policy_document.vpc_flow_log_kms_policy[0].json,
  ] : []
}
