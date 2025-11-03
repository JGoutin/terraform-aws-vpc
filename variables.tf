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
  description = "If true, enable VPC flow log."
  type        = bool
  default     = true
}

variable "vpc_flow_log_retention_days" {
  description = "VPC flow log retention days."
  type        = number
  default     = 7
}

variable "vpc_endpoints_services" {
  description = "List of AWS services endpoints to give access to the application."
  type        = list(string)
  default     = []
}

variable "vpc_endpoints_allowed" {
  description = "If true, VPC endpoints interfaces are privileged to give AWS services access to the application if no internet access is required. VPC endpoint Gateway are always provisioned. Disable only if cost is privileged over security."
  type        = bool
  default     = true
}

variable "nat_gateways_allowed" {
  description = "If true, NAT gateways are used to give internet access to the application. If Disabled and internet access is required, application subnets will be public. Disable only if cost is privileged over security. "
  type        = bool
  default     = true
}

variable "availability_zones_count" {
  description = "Maximum count of availability zones to provision with the dedicated VPC. Default to all available availability zones."
  type        = number
  default     = null
}

variable "internet_access_allowed" {
  description = "If true, allow internet access."
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
  description = "If true, create public subnets that can access application servers in app subnets. Cannot be used with external subnets (subnets_ids)."
  type        = bool
  default     = false
  validation {
    condition     = !var.public_subnets_enabled || length(var.subnets_ids) == 0
    error_message = "public_subnets_enabled cannot be enabled when using external subnets (subnets_ids). Public subnets are only created when provisioning a dedicated VPC."
  }
}

variable "public_to_app_ports" {
  description = "Map of ports for public subnet to app server communication. Each entry must specify from_port. Optional: to_port (defaults to from_port), protocol (defaults to 'tcp')."
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
  description = "Map of ports to expose on public subnets from internet. Each entry must specify from_port. Optional: to_port (defaults to from_port), protocol (defaults to 'tcp')."
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
