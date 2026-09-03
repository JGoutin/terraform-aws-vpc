variable "name_prefix" {
  description = "Prefix to add to all created resources names."
  type        = string
  default     = "network"
}

variable "subnets_ids" {
  description = "If specified, directly use theses subnets instead of creating a dedicated VPC."
  type        = list(string)
  default     = []
}

variable "security_group_id" {
  description = "If specified and 'subnet_ids' is specified, use this security group instead of creating a new one giving access to internet and AWS services."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_flow_log_enabled" {
  description = "If true, enable VPC flow log. Security Hub: EC2.6 (VPC flow logging should be enabled in all VPCs) — default true = pass; setting false fails this control."
  type        = bool
  default     = true
}

variable "vpc_flow_log_retention_days" {
  description = "VPC flow log retention days. Security Hub: CloudWatch.16 (CloudWatch log groups should be retained for a specified time period) requires at least 365 days by default — default 365 = pass; lowering it fails this control."
  type        = number
  default     = 365
}

variable "vpc_endpoints_services" {
  description = "List of AWS services endpoints to give access to the application. See also var.compliance_vpc_endpoints_enabled and var.guardduty_vpc_endpoint_enabled, which extend this list automatically."
  type        = list(string)
  default     = []
}

variable "vpc_endpoints_allowed" {
  description = "If true, VPC endpoints interfaces are privileged to give AWS services access to the application if no internet access is required. VPC endpoint Gateway are always provisioned. Disable only if cost is privileged over security. Security Hub: must be true for var.compliance_vpc_endpoints_enabled and var.guardduty_vpc_endpoint_enabled to take effect."
  type        = bool
  default     = true
}

variable "compliance_vpc_endpoints_enabled" {
  description = "If true, add the interface VPC endpoints for ECR API ('ecr.api'), ECR Docker Registry ('ecr.dkr'), Systems Manager ('ssm'), SSM Incident Manager Contacts ('ssm-contacts') and SSM Incident Manager ('ssm-incidents'), on top of any explicitly listed services in var.vpc_endpoints_services. Enable only if you have high compliance requirements — each interface endpoint adds cost. Enforced whenever a netdev (private) subnet exists, regardless of var.internet_access_allowed/var.nat_gateways_allowed; not possible in the public-subnet architecture (var.internet_access_allowed=true with var.nat_gateways_allowed=false), which has no private subnet to host the endpoints. Ignored if var.vpc_endpoints_allowed is false. Security Hub: EC2.55/EC2.56/EC2.57/EC2.58/EC2.60 — default false = fail; set to true to pass."
  type        = bool
  default     = false
}

variable "guardduty_vpc_endpoint_enabled" {
  description = "If true, add the 'guardduty-data' interface VPC endpoint. Only relevant if you use GuardDuty Runtime Monitoring on resources in this VPC — leave false otherwise. Recommended whenever Runtime Monitoring is enabled, even with GuardDuty's automated agent configuration: letting GuardDuty create its own endpoint does not guarantee placement in this module's netdev subnets, and that automatic creation can fail; enabling this takes priority over GuardDuty's own creation and ensures it lands in the correct subnets. Enforced whenever a netdev (private) subnet exists, regardless of var.internet_access_allowed/var.nat_gateways_allowed — not possible in the public-subnet architecture (var.internet_access_allowed=true with var.nat_gateways_allowed=false), which has no private subnet to host it. Ignored if var.vpc_endpoints_allowed is false. Not mapped to a Security Hub control; default false = endpoint not created."
  type        = bool
  default     = false
}

variable "nat_gateways_allowed" {
  description = "If true, NAT gateways are used to give internet access to the application. If Disabled and internet access is required, application subnets will be public. Disable only if cost is privileged over security. Security Hub: default true avoids the EC2.15 (subnets should not automatically assign public IP addresses) failure mode that occurs when this is false while var.internet_access_allowed is true, which makes app subnets public."
  type        = bool
  default     = true
}

variable "availability_zones_count" {
  description = "Maximum count of availability zones to provision with the dedicated VPC. Default to all available availability zones."
  type        = number
  default     = null
}

variable "internet_access_allowed" {
  description = "If true, allow internet access. Security Hub: default false = pass for EC2.15 (subnets should not automatically assign public IP addresses); combining true here with var.nat_gateways_allowed = false fails EC2.15 by making app subnets public."
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "If specified, directly use this KMS key instead of creating a dedicated one for the application."
  type        = string
  default     = null
}

variable "kms_policy_dependency" {
  description = "To use with 'depends_on' for resources requiring that KMS policy for key from this module is updated before creation. Only if var.kms_key_id is not set."
  type        = list(any)
  default     = []
}

variable "public_subnets_enabled" {
  description = "If true, create public subnets that can access application servers in app subnets. Cannot be used with external subnets (subnets_ids). Security Hub: default false = pass for EC2.15 (subnets should not automatically assign public IP addresses); enabling this intentionally fails EC2.15 for the public subnet tier only."
  type        = bool
  default     = false
  validation {
    condition     = !var.public_subnets_enabled || length(var.subnets_ids) == 0
    error_message = "public_subnets_enabled cannot be enabled when using external subnets (subnets_ids). Public subnets are only created when provisioning a dedicated VPC."
  }
}

variable "public_to_app_ports" {
  description = "Map of ports for public subnet to app server communication. Each entry must specify from_port. Optional: to_port (defaults to from_port), protocol (defaults to 'tcp'). Security Hub: EC2.21 (Network ACLs should not allow ingress from 0.0.0.0/0 to port 22 or port 3389) — default (port 8000) = pass; adding an entry with from_port/to_port covering 22 or 3389 fails it."
  type = map(object({
    from_port = number
    to_port   = optional(number)
    protocol  = optional(string, "tcp")
  }))
  default = {
    "http" = {
      from_port = 8000
    }
  }
}

variable "public_ingress_ports" {
  description = "Map of ports to expose on public subnets from internet. Each entry must specify from_port. Optional: to_port (defaults to from_port), protocol (defaults to 'tcp'). Security Hub: EC2.21 (Network ACLs should not allow ingress from 0.0.0.0/0 to port 22 or port 3389) — default (port 443) = pass; adding an entry with from_port/to_port covering 22 or 3389 fails it."
  type = map(object({
    from_port = number
    to_port   = optional(number)
    protocol  = optional(string, "tcp")
  }))
  default = {
    "https" = {
      from_port = 443
    }
  }
}

variable "internet_to_app_ports" {
  description = "Map of ports the internet can open on app servers in app subnets, on top of the replies to the requests they make themselves. Each entry must specify from_port. Optional: to_port (defaults to from_port), protocol (defaults to 'tcp'). Network ACLs are stateless, so each entry also opens the ephemeral range 1024-65535 in egress for the same protocol, which is where the reply goes. Applied to both 0.0.0.0/0 and ::/0, and only where the module provisions an internet path: var.internet_access_allowed = true, or interface endpoints required by var.vpc_endpoints_services while var.vpc_endpoints_allowed = false. Like the module's own internet rules, a narrower source belongs to the security group in front, and a network ACL wider than that security group grants nothing. Traffic only actually arrives over IPv4 where the app subnets are public (var.nat_gateways_allowed = false) and the workload takes a public address; over IPv6 the app subnets egress through an egress-only internet gateway, which admits no externally initiated connection. Cannot be used with external subnets (subnets_ids). Security Hub: EC2.21 (Network ACLs should not allow ingress from 0.0.0.0/0 to port 22 or port 3389) — default (empty) = pass; adding an entry with from_port/to_port covering 22 or 3389 fails it."
  type = map(object({
    from_port = number
    to_port   = optional(number)
    protocol  = optional(string, "tcp")
  }))
  default = {}
  validation {
    condition     = length(var.internet_to_app_ports) == 0 || length(var.subnets_ids) == 0
    error_message = "internet_to_app_ports cannot be used with external subnets (subnets_ids). The application network ACL it adds rules to is only created when provisioning a dedicated VPC."
  }
  validation {
    condition = alltrue([
      for entry in values(var.internet_to_app_ports) :
      entry.from_port >= 0 && coalesce(entry.to_port, entry.from_port) >= entry.from_port && coalesce(entry.to_port, entry.from_port) <= 65535
    ])
    error_message = "internet_to_app_ports entries must have 0 <= from_port <= to_port <= 65535, to_port defaulting to from_port."
  }
}

variable "app_to_internet_ports" {
  description = "Map of ports app servers in app subnets can open on the internet, on top of the TCP 443 already opened. Each entry must specify from_port. Optional: to_port (defaults to from_port), protocol (defaults to 'tcp'). Network ACLs are stateless, so each entry also opens the ephemeral range 1024-65535 in ingress for the same protocol, which is where the reply comes back. The module already opens that range in ingress for TCP only, so an entry with another protocol genuinely opens it for that protocol: the module cannot know which local ports the workload binds, so the whole range is opened. Applied to both 0.0.0.0/0 and ::/0, and only where the module provisions an internet path: var.internet_access_allowed = true, or interface endpoints required by var.vpc_endpoints_services while var.vpc_endpoints_allowed = false. Like the module's own internet rules, a narrower destination belongs to the security group in front, and a network ACL wider than that security group grants nothing. Cannot be used with external subnets (subnets_ids). Security Hub: EC2.21 (Network ACLs should not allow ingress from 0.0.0.0/0 to port 22 or port 3389) — default (empty) = pass; the only ingress an entry adds is that ephemeral range in the entry's own protocol, so a 'tcp' entry adds nothing the module doesn't already open, and the egress rule still widens what the app tier may reach, so list only the ports and protocols the workload calls out on."
  type = map(object({
    from_port = number
    to_port   = optional(number)
    protocol  = optional(string, "tcp")
  }))
  default = {}
  validation {
    condition     = length(var.app_to_internet_ports) == 0 || length(var.subnets_ids) == 0
    error_message = "app_to_internet_ports cannot be used with external subnets (subnets_ids). The application network ACL it adds rules to is only created when provisioning a dedicated VPC."
  }
  validation {
    condition = alltrue([
      for entry in values(var.app_to_internet_ports) :
      entry.from_port >= 0 && coalesce(entry.to_port, entry.from_port) >= entry.from_port && coalesce(entry.to_port, entry.from_port) <= 65535
    ])
    error_message = "app_to_internet_ports entries must have 0 <= from_port <= to_port <= 65535, to_port defaulting to from_port."
  }
}

variable "dns_firewall_enabled" {
  description = "If true, create a Route 53 Resolver DNS Firewall rule group and associate it with this module's dedicated VPC, blocking/alerting on DNS queries per var.dns_firewall_managed_domain_lists and var.dns_firewall_advanced_enabled. Only supported for the VPC this module creates; cannot be enabled when using external subnets (subnets_ids). Not mapped to a Security Hub control; default false = feature not created."
  type        = bool
  default     = false
  validation {
    condition     = !var.dns_firewall_enabled || length(var.subnets_ids) == 0
    error_message = "dns_firewall_enabled cannot be enabled when using external subnets (subnets_ids). DNS Firewall is only supported for the dedicated VPC managed by this module."
  }
}

variable "dns_firewall_managed_domain_list_ids" {
  description = "Map of AWS Managed Domain List name to ID (e.g. { \"AWSManagedDomainsAggregateThreatList\" = \"rslvr-fdl-...\" }) to block/alert on via var.dns_firewall_action. Defaults (null) to this module's built-in Aggregate Threat List ID for the current region (see local.dns_firewall_default_managed_domain_list_ids in dns_firewall.tf), covering commercial regions enabled by default. IDs are region-specific and can't be resolved from within Terraform, so for a region not in that table look yours up with: 'aws route53resolver list-firewall-domain-lists --query \"FirewallDomainLists[?ManagedOwnerName=='Route 53 Resolver DNS Firewall']\"'. Ignored if var.dns_firewall_enabled is false. Set to {} to skip managed-list rules while still using var.dns_firewall_advanced_enabled."
  type        = map(string)
  default     = null
}

variable "dns_firewall_action" {
  description = "Action taken by DNS Firewall when a query matches a domain from var.dns_firewall_managed_domain_list_ids, and (if var.dns_firewall_advanced_enabled) a DNS Firewall Advanced threat detection. Valid values: 'ALLOW', 'BLOCK', 'ALERT'. 'ALLOW' isn't valid for DNS Firewall Advanced rules, so it's treated as 'BLOCK' for those only. Ignored if var.dns_firewall_enabled is false."
  type        = string
  default     = "BLOCK"
  validation {
    condition     = contains(["ALLOW", "BLOCK", "ALERT"], var.dns_firewall_action)
    error_message = "dns_firewall_action must be one of: ALLOW, BLOCK, ALERT."
  }
}

variable "dns_firewall_advanced_enabled" {
  description = "If true, add Route 53 Resolver DNS Firewall Advanced rules blocking DNS queries identified as domain generation algorithm (DGA) or DNS tunneling activity, on top of any managed-domain-list rules. Ignored if var.dns_firewall_enabled is false."
  type        = bool
  default     = false
}

variable "dns_firewall_advanced_confidence_threshold" {
  description = "Confidence threshold for DNS Firewall Advanced rules. Valid values: 'LOW', 'MEDIUM', 'HIGH'. Lower thresholds catch more threats at the cost of more false positives. Ignored if var.dns_firewall_advanced_enabled is false."
  type        = string
  default     = "HIGH"
  validation {
    condition     = contains(["LOW", "MEDIUM", "HIGH"], var.dns_firewall_advanced_confidence_threshold)
    error_message = "dns_firewall_advanced_confidence_threshold must be one of: LOW, MEDIUM, HIGH."
  }
}

variable "dns_firewall_priority" {
  description = "Processing priority for this module's DNS Firewall rule group association within the VPC (lower is processed first). Must be unique among all rule group associations on the same VPC, including ones created outside this module. Ignored if var.dns_firewall_enabled is false."
  type        = number
  default     = 101
}

variable "tags" {
  description = "Additional tags to apply to created resources. Security Hub: most tagging controls (EC2.37/39/40/41/42/43/44/46/174) always pass regardless of this value since a Name tag is always merged in; EC2.48 (VPC flow logs should be tagged) and IAM.24 (IAM roles should be tagged, for the flow log role) apply this value directly with no fallback — default null fails both; set tags to pass."
  type        = map(string)
  default     = null
}
