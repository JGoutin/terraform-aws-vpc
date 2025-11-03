# AWS VPC Infrastructure Module

Reusable Terraform module for creating secure, production-ready VPC infrastructure with multi-AZ subnets, NAT gateways, VPC endpoints, and monitoring.

## Overview

This module provides a complete AWS VPC networking solution designed for secure, scalable cloud deployments.

**Core Components:**
- VPC with customizable CIDR block
- Multi-AZ public and private subnets
- NAT Gateways for secure internet access
- VPC Endpoints for AWS service connectivity
- VPC Flow Logs for security monitoring
- Security groups and network ACLs

## Features

### Network Design
- ✅ **Multi-AZ Deployment** - High availability across availability zones
- ✅ **Public/Private Subnets** - Secure architecture
- ✅ **NAT Gateways** - Private subnet internet access
- ✅ **IPv6 Support** - Optional dual-stack networking

### VPC Endpoints
- ✅ **Gateway Endpoints** - S3, DynamoDB (no cost)
- ✅ **Interface Endpoints** - ECR, ECS, Secrets Manager, SSM, Logs, STS, Bedrock
- ✅ **Cost Optimization** - Optional endpoint configuration

### Security
- ✅ **VPC Flow Logs** - Network traffic monitoring
- ✅ **Private Subnets** - Isolated application layer
- ✅ **Network ACLs** - Subnet-level filtering
- ✅ **Route Tables** - Controlled traffic routing

### Flexibility
- ✅ **Configurable CIDR** - Custom IP ranges
- ✅ **Variable AZ Count** - 1-6 availability zones
- ✅ **Public/Private Balance** - Adjust subnet distribution
- ✅ **Optional Components** - Disable NAT/endpoints for cost

## Quick Start

### Minimal Example

```hcl
module "vpc" {
  source = "JGoutin/vpc/aws"
  
  name = "my-vpc"
  cidr = "10.0.0.0/16"
}
```

Creates VPC with default settings: 2 public + 2 private subnets, NAT gateways, VPC endpoints.

### Production Example

```hcl
module "vpc" {
  source = "JGoutin/vpc/aws"
  
  name                     = "production-vpc"
  cidr                     = "10.0.0.0/16"
  availability_zones_count = 3
  
  # Subnets
  subnet_public_count  = 3
  subnet_private_count = 3
  
  # Networking
  enable_nat_gateway = true
  enable_ipv6        = false
  
  # VPC Endpoints
  vpc_endpoints_allowed = true
  
  # Monitoring
  enable_flow_log               = true
  flow_log_retention_in_days    = 90
  flow_log_max_aggregation_interval = 60
  
  tags = {
    Environment = "production"
    Project     = "my-app"
  }
}
```

### Cost-Optimized Example

```hcl
module "vpc" {
  source = "JGoutin/vpc/aws"
  
  name = "cost-optimized-vpc"
  cidr = "10.0.0.0/16"
  
  # Use public subnets instead of NAT gateways
  enable_nat_gateway = false
  
  # Disable interface endpoints (keep gateway endpoints)
  vpc_endpoints_allowed = false
  
  # Disable flow logs
  enable_flow_log = false
}
```

Saves ~$35-45/month by eliminating NAT Gateway and VPC endpoints.

## Architecture

### Standard Configuration (NAT Gateway)

```
┌────────────────────────────────────────────────┐
│                  Internet                       │
└─────────────┬──────────────────────────────────┘
              │
      ┌───────▼────────┐
      │ Internet Gateway│
      └───────┬────────┘
              │
┌─────────────┼────────────────────────────────────┐
│     VPC     │                                    │
│             │                                    │
│  ┌──────────▼──────────┐   ┌──────────────────┐ │
│  │  Public Subnet A    │   │  Public Subnet B │ │
│  │  ┌──────────────┐   │   │  ┌─────────────┐ │ │
│  │  │ NAT Gateway  │   │   │  │ NAT Gateway │ │ │
│  │  └──────┬───────┘   │   │  └──────┬──────┘ │ │
│  └─────────┼───────────┘   └─────────┼────────┘ │
│            │                         │          │
│  ┌─────────▼───────────┐   ┌─────────▼────────┐ │
│  │  Private Subnet A   │   │  Private Subnet B│ │
│  │  ┌──────────────┐   │   │  ┌─────────────┐ │ │
│  │  │     ECS      │   │   │  │     ECS     │ │ │
│  │  └──────────────┘   │   │  └─────────────┘ │ │
│  └─────────────────────┘   └──────────────────┘ │
│            │                         │          │
│  ┌─────────▼─────────────────────────▼────────┐ │
│  │         VPC Endpoints (Interface)          │ │
│  │  ECR, ECS, Secrets, SSM, Logs, Bedrock    │ │
│  └────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

## Subnet Distribution

Module automatically calculates CIDR blocks:

**Example: 10.0.0.0/16 with 2 public + 2 private subnets:**
- Public Subnet A: 10.0.0.0/24 (10.0.0.1 - 10.0.0.254)
- Public Subnet B: 10.0.1.0/24 (10.0.1.1 - 10.0.1.254)
- Private Subnet A: 10.0.2.0/24 (10.0.2.1 - 10.0.2.254)
- Private Subnet B: 10.0.3.0/24 (10.0.3.1 - 10.0.3.254)

## VPC Endpoints

### Gateway Endpoints (Free)
- **S3** - Always created
- **DynamoDB** - Always created

### Interface Endpoints (Conditional)

Created when `vpc_endpoints_allowed = true`:

| Endpoint | Use Case | Cost/month* |
|----------|----------|-------------|
| ECR API | Container registry | ~$7 |
| ECR DKR | Docker images | ~$7 |
| ECS | Task management | ~$7 |
| ECS Telemetry | Container Insights | ~$7 |
| Secrets Manager | Secrets access | ~$7 |
| SSM | Parameter Store | ~$7 |
| CloudWatch Logs | Logging | ~$7 |
| STS | IAM credentials | ~$7 |
| Bedrock Runtime | AI inference | ~$7 |

*Approximate per AZ in us-east-1*

**Total for all interface endpoints:** ~$14-21/month (depending on AZ count)

**When to disable:**
- Development environments
- Cost-sensitive deployments
- Public subnet architectures

## NAT Gateway vs Public Subnets

### NAT Gateway (Secure)

```hcl
enable_nat_gateway = true
```

**Pros:**
- Private subnets (no public IPs)
- Better security
- Centralized egress control

**Cons:**
- ~$32-45/month per gateway
- Data transfer charges

### Public Subnets (Cost-Optimized)

```hcl
enable_nat_gateway = false
```

**Pros:**
- No NAT Gateway costs
- Free data transfer (outbound)
- Simpler architecture

**Cons:**
- Resources get public IPs
- Less secure
- Harder to audit egress

## VPC Flow Logs

Network traffic monitoring for security and compliance:

```hcl
enable_flow_log               = true
flow_log_retention_in_days    = 90
flow_log_max_aggregation_interval = 60  # seconds
```

**Use cases:**
- Security incident investigation
- Compliance auditing (PCI-DSS, HIPAA)
- Network troubleshooting
- Cost analysis

**Cost:** ~$0.50/GB ingested + storage

## IPv6 Support

Enable dual-stack networking:

```hcl
enable_ipv6 = true
```

Automatically assigns:
- VPC IPv6 CIDR block (/56)
- Subnet IPv6 CIDR blocks (/64)
- IGW egress-only gateway
- Route table entries

## Use Cases

- **Microservices** - Service mesh deployments
- **Web Applications** - Public + private tier architecture
- **Data Processing** - Secure data lake infrastructure
- **Compliance Workloads** - HIPAA, PCI-DSS, SOC 2
- **Hybrid Cloud** - VPN/Direct Connect integration
- **Multi-Region** - Consistent VPC architecture

## Outputs

Key outputs for resource integration:

- `vpc_id` - For security groups, resources
- `public_subnet_ids` - For ALB, NAT
- `private_subnet_ids` - For ECS, RDS, Lambda
- `vpc_endpoints` - Endpoint IDs
- `nat_gateway_public_ips` - For firewall rules
- `availability_zones` - AZ list

## Requirements

- **Terraform/OpenTofu**: >= 1.5.0
- **AWS Provider**: >= 5.0
- **AWS Region**: Any region with VPC support

## Best Practices

1. **Use NAT Gateways** for production deployments (enhanced security)
2. **Enable Flow Logs** for compliance auditing and troubleshooting
3. **Deploy VPC Endpoints** to reduce data transfer costs and improve security
4. **Spread across 3 AZs** minimum for high availability
5. **Separate public/private tiers** for defense in depth architecture
6. **Tag all resources** consistently for cost allocation and management

---

# Terraform Documentation

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >=5 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_app_ipv4_cidr"></a> [app\_ipv4\_cidr](#module\_app\_ipv4\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_app_ipv6_cidr"></a> [app\_ipv6\_cidr](#module\_app\_ipv6\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_kms_key"></a> [kms\_key](#module\_kms\_key) | ../module-kms-key | n/a |
| <a name="module_netdev_ipv4_cidr"></a> [netdev\_ipv4\_cidr](#module\_netdev\_ipv4\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_netdev_ipv6_cidr"></a> [netdev\_ipv6\_cidr](#module\_netdev\_ipv6\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_public_ipv4_cidr"></a> [public\_ipv4\_cidr](#module\_public\_ipv4\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_public_ipv6_cidr"></a> [public\_ipv6\_cidr](#module\_public\_ipv6\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_vpc_ipv4_cidr"></a> [vpc\_ipv4\_cidr](#module\_vpc\_ipv4\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_vpc_ipv6_cidr"></a> [vpc\_ipv6\_cidr](#module\_vpc\_ipv6\_cidr) | hashicorp/subnets/cidr | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.vpc_flow_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_egress_only_internet_gateway.netdev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/egress_only_internet_gateway) | resource |
| [aws_eip.netdev_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.vpc_flow_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.vpc_flow_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.netdev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.netdev_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_network_acl.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_network_acl.netdev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_network_acl.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_network_acl_association.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_association) | resource |
| [aws_network_acl_association.netdev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_association) | resource |
| [aws_network_acl_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_association) | resource |
| [aws_network_acl_rule.app_ipv4_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.app_ipv4_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.app_ipv6_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.app_ipv6_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.netdev_ipv4_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.netdev_ipv4_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.netdev_ipv6_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.netdev_ipv6_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_ipv4_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_ipv4_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_ipv6_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.public_ipv6_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_route.netdev_app_to_nat_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.netdev_app_to_web_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.netdev_app_to_web_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.netdev_nat_to_web_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_to_internet_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_to_internet_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.netdev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.netdev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.netdev_vpce](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.netdev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_dhcp_options.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options) | resource |
| [aws_vpc_dhcp_options_association.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options_association) | resource |
| [aws_vpc_endpoint.netdev_vpce_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.netdev_vpce_interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint_route_table_association.netdev_app_to_vpce](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_route_table_association) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.vpc_flow_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vpc_flow_log_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vpc_flow_log_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc_endpoint_service.netdev_vpce_interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc_endpoint_service) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones_count"></a> [availability\_zones\_count](#input\_availability\_zones\_count) | Maximum count of availability zones to provision with the dedicated VPC. Default to all available availability zones. | `number` | `null` | no |
| <a name="input_internet_access_allowed"></a> [internet\_access\_allowed](#input\_internet\_access\_allowed) | If true, allow internet access. | `bool` | `false` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | If specified, directly use this KMS key instead of creating a dedicated one for the application. | `string` | `null` | no |
| <a name="input_kms_policy_dependency"></a> [kms\_policy\_dependency](#input\_kms\_policy\_dependency) | To use with 'depends\_on' for resources requiring that KMS policy for key from this module is updated before creation. Only if var.kms\_key\_id is not set. | `list(any)` | `[]` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix to add to all created resources names. | `string` | `"network"` | no |
| <a name="input_nat_gateways_allowed"></a> [nat\_gateways\_allowed](#input\_nat\_gateways\_allowed) | If true, NAT gateways are used to give internet access to the application. If Disabled and internet access is required, application subnets will be public. Disable only if cost is privileged over security. | `bool` | `true` | no |
| <a name="input_public_ingress_ports"></a> [public\_ingress\_ports](#input\_public\_ingress\_ports) | Map of ports to expose on public subnets from internet. Each entry must specify from\_port. Optional: to\_port (defaults to from\_port), protocol (defaults to 'tcp'). | <pre>map(object({<br/>    from_port = number<br/>    to_port   = optional(number)<br/>    protocol  = optional(string, "tcp")<br/>  }))</pre> | <pre>{<br/>  "https": {<br/>    "from_port": 443<br/>  }<br/>}</pre> | no |
| <a name="input_public_subnets_enabled"></a> [public\_subnets\_enabled](#input\_public\_subnets\_enabled) | If true, create public subnets that can access application servers in app subnets. Cannot be used with external subnets (subnets\_ids). | `bool` | `false` | no |
| <a name="input_public_to_app_ports"></a> [public\_to\_app\_ports](#input\_public\_to\_app\_ports) | Map of ports for public subnet to app server communication. Each entry must specify from\_port. Optional: to\_port (defaults to from\_port), protocol (defaults to 'tcp'). | <pre>map(object({<br/>    from_port = number<br/>    to_port   = optional(number)<br/>    protocol  = optional(string, "tcp")<br/>  }))</pre> | <pre>{<br/>  "http": {<br/>    "from_port": 8000<br/>  }<br/>}</pre> | no |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | If specified and 'subnet\_ids' is specified, use this security group instead of creating a new one giving access to internet and AWS services. | `string` | `null` | no |
| <a name="input_subnets_ids"></a> [subnets\_ids](#input\_subnets\_ids) | If specified, directly use theses subnets instead of creating a dedicated VPC. | `list(string)` | `[]` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the dedicated VPC. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_endpoints_allowed"></a> [vpc\_endpoints\_allowed](#input\_vpc\_endpoints\_allowed) | If true, VPC endpoints interfaces are privileged to give AWS services access to the application if no internet access is required. VPC endpoint Gateway are always provisioned. Disable only if cost is privileged over security. | `bool` | `true` | no |
| <a name="input_vpc_endpoints_services"></a> [vpc\_endpoints\_services](#input\_vpc\_endpoints\_services) | List of AWS services endpoints to give access to the application. | `list(string)` | `[]` | no |
| <a name="input_vpc_flow_log_enabled"></a> [vpc\_flow\_log\_enabled](#input\_vpc\_flow\_log\_enabled) | If true, enable VPC flow log. | `bool` | `true` | no |
| <a name="input_vpc_flow_log_retention_days"></a> [vpc\_flow\_log\_retention\_days](#input\_vpc\_flow\_log\_retention\_days) | VPC flow log retention days. | `number` | `7` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ipv6_enabled"></a> [ipv6\_enabled](#output\_ipv6\_enabled) | Whether IPv6 is enabled on the VPC. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | KMS key ARN. |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | KMS key ID. |
| <a name="output_kms_policy_dependency"></a> [kms\_policy\_dependency](#output\_kms\_policy\_dependency) | To use with 'depends\_on' for resources requiring that KMS policy is updated before creation. Only if var.kms\_key\_id is set. |
| <a name="output_kms_policy_documents_json"></a> [kms\_policy\_documents\_json](#output\_kms\_policy\_documents\_json) | KMS policy documents to add to the policy of the key specified via var.kms\_key\_id. |
| <a name="output_public_subnets_ids"></a> [public\_subnets\_ids](#output\_public\_subnets\_ids) | Public subnets IDs. Empty list if public subnets are not enabled. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security groups ID. |
| <a name="output_subnets_ids"></a> [subnets\_ids](#output\_subnets\_ids) | Subnets ID. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID. |
