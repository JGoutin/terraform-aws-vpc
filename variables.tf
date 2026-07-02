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

variable "tags" {
  description = "Additional tags to apply to created resources. Security Hub: most tagging controls (EC2.37/39/40/41/42/43/44/46/174) always pass regardless of this value since a Name tag is always merged in; EC2.48 (VPC flow logs should be tagged) and IAM.24 (IAM roles should be tagged, for the flow log role) apply this value directly with no fallback — default null fails both; set tags to pass."
  type        = map(string)
  default     = null
}
