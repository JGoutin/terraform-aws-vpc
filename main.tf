/*
Network configuration
*/

locals {
  region             = data.aws_region.current.region
  vpc_enabled        = length(var.subnets_ids) == 0
  vpc_resource_count = local.vpc_enabled ? 1 : 0

  # A VPC this module creates always receives an IPv6 block, so its own configuration
  # answers; provided subnets are whatever the caller built, so they have to be asked.
  # Reported from the first one, matching how a consumer picks the subnet that decides
  # a dual-stack behavior, rather than requiring every subnet to agree. The provider
  # reports "no IPv6" as an empty string, not null, so that's what's compared against.
  ipv6_enabled = local.vpc_enabled || try(data.aws_subnet.app[0].ipv6_cidr_block, "") != ""

  # Tags to merge into resources that already carry a Name tag
  tags = coalesce(var.tags, {})
  vpc_availability_zones = toset(
    local.vpc_enabled ? (
      var.availability_zones_count != null ?
      slice(sort(data.aws_availability_zones.available[0].names), 0, var.availability_zones_count) :
      data.aws_availability_zones.available[0].names
    )
  : [])

  # AWS services requirements
  vpce_gateway_services_all = ["s3", "dynamodb"]
  # Interface endpoints required to pass Security Hub EC2.55 (ECR API), EC2.56 (ECR DKR), EC2.57 (SSM),
  # EC2.58 (SSM Incident Manager Contacts) and EC2.60 (SSM Incident Manager).
  vpce_compliance_services = var.compliance_vpc_endpoints_enabled ? ["ecr.api", "ecr.dkr", "ssm", "ssm-contacts", "ssm-incidents"] : []
  # Interface endpoint required by GuardDuty Runtime Monitoring when the security agent is installed manually.
  # Also created when using GuardDuty's automated agent configuration: that mechanism creates its own endpoint
  # but doesn't guarantee placement in this module's netdev subnets and can fail, so managing it here whenever
  # requested takes priority over leaving it to GuardDuty.
  vpce_guardduty_services = var.guardduty_vpc_endpoint_enabled ? ["guardduty-data"] : []
  # Enforced endpoints: created whenever a netdev (private) subnet exists (see vpce_enforced_enabled below),
  # regardless of var.internet_access_allowed/var.nat_gateways_allowed.
  vpce_enforced_services = concat(local.vpce_compliance_services, local.vpce_guardduty_services)

  # Non-enforced (caller-supplied only) interface endpoints: only created when there is no direct internet
  # route, same cost-driven behavior as before var.compliance_vpc_endpoints_enabled/var.guardduty_vpc_endpoint_enabled existed.
  vpce_gateway_services                  = setintersection(var.vpc_endpoints_services, local.vpce_gateway_services_all)
  vpce_interfaces_services_opportunistic = setsubtract(var.vpc_endpoints_services, local.vpce_gateway_services_all)
  vpce_interfaces_required               = length(local.vpce_interfaces_services_opportunistic) > 0

  # Network egress access
  internet_required     = var.internet_access_allowed || (local.vpce_interfaces_required && !var.vpc_endpoints_allowed)
  nat_gateways_enabled  = local.internet_required && var.nat_gateways_allowed && local.vpc_enabled
  public_subnet_enabled = local.internet_required && !var.nat_gateways_allowed && local.vpc_enabled

  # The netdev (private) subnets exist whenever the app tier isn't directly public.
  vpce_netdev_available = local.vpc_enabled && !local.public_subnet_enabled

  # Opportunistic endpoints: created only when there's no direct internet route (existing cost-driven behavior).
  vpce_opportunistic_enabled = local.vpce_interfaces_required && var.vpc_endpoints_allowed && !local.internet_required && local.vpce_netdev_available

  # Enforced endpoints (compliance + GuardDuty): created whenever physically possible (a netdev subnet
  # exists), regardless of var.internet_access_allowed / var.nat_gateways_allowed. Still impossible in the
  # public-subnet (var.internet_access_allowed=true, var.nat_gateways_allowed=false) architecture, since no
  # private subnet exists there to host the endpoint's ENI.
  vpce_enforced_enabled = var.vpc_endpoints_allowed && local.vpce_netdev_available && length(local.vpce_enforced_services) > 0

  # True if any interface endpoint (opportunistic or enforced) will be created — used to gate the netdev
  # security group, NACL rules and app-tier route needed to reach it.
  vpce_interfaces_enabled = local.vpce_opportunistic_enabled || local.vpce_enforced_enabled

  vpce_interfaces_services = distinct(concat(
    local.vpce_opportunistic_enabled ? tolist(local.vpce_interfaces_services_opportunistic) : [],
    local.vpce_enforced_enabled ? local.vpce_enforced_services : [],
  ))
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
  version = "~> 1.2"

  id                = var.kms_key_id
  name_prefix       = var.name_prefix
  tags              = local.tags
  policy_dependency = var.kms_policy_dependency
  policy_documents_json = local.vpc_flow_log_enabled ? [
    data.aws_iam_policy_document.vpc_flow_log_kms_policy[0].json,
  ] : []
}
