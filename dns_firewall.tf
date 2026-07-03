/*
Route 53 Resolver DNS Firewall

Only supported for this module's own dedicated VPC (local.vpc_enabled); managing DNS Firewall on a
customer-supplied VPC (var.subnets_ids) is out of scope, enforced by var.dns_firewall_enabled's validation.

AWS Managed Domain List IDs are region-specific and can't be resolved from within Terraform (no data
source supports name-based lookup).
Since these IDs are stable AWS-owned identifiers (verified identical across unrelated accounts in the same region),
the Aggregate Threat List ID for each commercial region enabled by default is instead baked in below,
resolved automatically from the current region unless var.dns_firewall_managed_domain_list_ids overrides it.
Regions requiring opt-in aren't covered; pass the ID explicitly there
(see var.dns_firewall_managed_domain_list_ids' description).
*/

locals {
  dns_firewall_enabled = local.vpc_enabled && var.dns_firewall_enabled
  dns_firewall_name    = "${var.name_prefix}-dnsfw-${local.region}"

  # Aggregate Threat List ID per region, as returned by `aws route53resolver list-firewall-domain-lists`.
  dns_firewall_default_managed_domain_list_ids = {
    ap-northeast-1 = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-103b4302c274455e" }
    ap-northeast-2 = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-1997a3cdd61a4f2a" }
    ap-northeast-3 = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-2e57899062984ed1" }
    ap-south-1     = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-d1159fcdd6b942cf" }
    ap-southeast-1 = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-49099fd7fc3d4853" }
    ap-southeast-2 = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-9be336ef32844e5" }
    ca-central-1   = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-46d873be30464a06" }
    eu-central-1   = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-54a2c1ef5b014042" }
    eu-central-2   = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-8cd4169f2bd1480f" }
    eu-north-1     = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-17764a248c141e9" }
    eu-south-1     = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-89f7b3e9074983" }
    eu-south-2     = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-8d0f4229b2734c50" }
    eu-west-1      = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-a88f2f26cc6a4296" }
    eu-west-2      = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-4e96d4ce77f466b" }
    eu-west-3      = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-6002172db5fc4cab" }
    sa-east-1      = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-5d3faeb3ed7a4492" }
    us-east-1      = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-15f4860b1ad54ead" }
    us-east-2      = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-bbc798062d594728" }
    us-west-1      = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-d2a6edeaa3b04a8a" }
    us-west-2      = { AWSManagedDomainsAggregateThreatList = "rslvr-fdl-d252ee1944404e15" }
  }

  dns_firewall_managed_domain_list_ids = local.dns_firewall_enabled ? coalesce(
    var.dns_firewall_managed_domain_list_ids,
    lookup(local.dns_firewall_default_managed_domain_list_ids, local.region, {})
  ) : {}
  dns_firewall_managed_rule_priorities = {
    for idx, name in sort(keys(local.dns_firewall_managed_domain_list_ids)) : name => 100 + idx
  }

  dns_firewall_advanced_enabled = local.dns_firewall_enabled && var.dns_firewall_advanced_enabled
  dns_firewall_advanced_rule_priorities = local.dns_firewall_advanced_enabled ? {
    "DGA"           = 200
    "DNS_TUNNELING" = 201
  } : {}
  # ALLOW is not a valid action for DNS Firewall Advanced rules; fall back to BLOCK since var.dns_firewall_action
  # otherwise applies as-is.
  dns_firewall_advanced_action = var.dns_firewall_action == "ALLOW" ? "BLOCK" : var.dns_firewall_action
}

resource "aws_route53_resolver_firewall_rule_group" "dns_firewall" {
  count = local.dns_firewall_enabled ? 1 : 0
  name  = local.dns_firewall_name
  tags  = merge(local.tags, { Name = local.dns_firewall_name })
}

resource "aws_route53_resolver_firewall_rule_group_association" "dns_firewall" {
  count                  = local.dns_firewall_enabled ? 1 : 0
  name                   = local.dns_firewall_name
  firewall_rule_group_id = aws_route53_resolver_firewall_rule_group.dns_firewall[0].id
  vpc_id                 = aws_vpc.vpc[0].id
  priority               = var.dns_firewall_priority
  mutation_protection    = "DISABLED"
  tags                   = merge(local.tags, { Name = local.dns_firewall_name })
}

resource "aws_route53_resolver_firewall_rule" "dns_firewall_managed" {
  for_each                = local.dns_firewall_managed_domain_list_ids
  name                    = "${local.dns_firewall_name}-managed-${local.dns_firewall_managed_rule_priorities[each.key]}"
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.dns_firewall[0].id
  firewall_domain_list_id = each.value
  priority                = local.dns_firewall_managed_rule_priorities[each.key]
  action                  = var.dns_firewall_action
  block_response          = var.dns_firewall_action == "BLOCK" ? "NODATA" : null
}

resource "aws_route53_resolver_firewall_rule" "dns_firewall_advanced" {
  for_each               = local.dns_firewall_advanced_rule_priorities
  name                   = "${local.dns_firewall_name}-${lower(each.key)}"
  firewall_rule_group_id = aws_route53_resolver_firewall_rule_group.dns_firewall[0].id
  dns_threat_protection  = each.key
  confidence_threshold   = var.dns_firewall_advanced_confidence_threshold
  priority               = each.value
  action                 = local.dns_firewall_advanced_action
  block_response         = local.dns_firewall_advanced_action == "BLOCK" ? "NODATA" : null
}
