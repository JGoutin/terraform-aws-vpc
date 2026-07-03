# AWS VPC Infrastructure Module

[![Terraform Module](https://img.shields.io/badge/Terraform-VPC%20module-844FBA?logo=terraform&logoColor=ffffff)](https://registry.terraform.io/modules/jgoutin/vpc/aws/latest)
[![OpenTofu Module](https://img.shields.io/badge/OpenTofu-VPC%20module-FFDA18?logo=opentofu&logoColor=ffffff)](https://search.opentofu.org/module/jgoutin/vpc/aws/latest)

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
- ✅ **IPv6 Support** - Dual-stack networking, always enabled

### VPC Endpoints
- ✅ **Gateway Endpoints** - S3, DynamoDB (no cost)
- ✅ **Interface Endpoints** - ECR, ECS, Secrets Manager, SSM, Logs, STS, Bedrock
- ✅ **Cost Optimization** - Optional endpoint configuration

### Security
- ✅ **VPC Flow Logs** - Network traffic monitoring
- ✅ **Private Subnets** - Isolated application layer
- ✅ **Network ACLs** - Subnet-level filtering
- ✅ **Route Tables** - Controlled traffic routing
- ✅ **DNS Firewall** - Optional Route 53 Resolver DNS Firewall with AWS managed threat lists and Advanced (DGA/DNS tunneling) detection

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
  
  name_prefix = "my-vpc"
  vpc_cidr    = "10.0.0.0/16"
}
```

Creates a VPC with default settings: private app subnets (one per AZ), NAT gateways, VPC endpoints, flow logs.

### Production Example

```hcl
module "vpc" {
  source = "JGoutin/vpc/aws"
  
  name_prefix              = "production-vpc"
  vpc_cidr                 = "10.0.0.0/16"
  availability_zones_count = 3
  
  # Networking
  nat_gateways_allowed = true
  
  # VPC Endpoints
  vpc_endpoints_allowed = true
  
  # Monitoring
  vpc_flow_log_enabled        = true
  vpc_flow_log_retention_days = 365
  
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
  
  name_prefix = "cost-optimized-vpc"
  vpc_cidr    = "10.0.0.0/16"
  
  # Use public subnets instead of NAT gateways
  nat_gateways_allowed = false
  
  # Disable interface endpoints (keep gateway endpoints)
  vpc_endpoints_allowed = false
  
  # Disable flow logs
  vpc_flow_log_enabled = false
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

Module automatically calculates CIDR blocks, one subnet per availability zone (`availability_zones_count`):

**Example: 10.0.0.0/16 with 2 AZs (2 public + 2 private subnets):**
- Public Subnet A: 10.0.0.0/24 (10.0.0.1 - 10.0.0.254)
- Public Subnet B: 10.0.1.0/24 (10.0.1.1 - 10.0.1.254)
- Private Subnet A: 10.0.2.0/24 (10.0.2.1 - 10.0.2.254)
- Private Subnet B: 10.0.3.0/24 (10.0.3.1 - 10.0.3.254)

## VPC Endpoints

### Gateway Endpoints (Free)
- **S3** - Always created
- **DynamoDB** - Always created

### Interface Endpoints (Conditional)

Requires `vpc_endpoints_allowed = true` (default) and the service listed in `vpc_endpoints_services`. `ecr.api`, `ecr.dkr`, `ssm`, `ssm-contacts` and `ssm-incidents` are added automatically when `compliance_vpc_endpoints_enabled = true` (default `false` — enable only if you have high compliance requirements, since each interface endpoint adds cost), and `guardduty-data` when `guardduty_vpc_endpoint_enabled = true` (default `false`). Unlike the other services below, these are all enforced whenever a private (netdev) subnet exists, even with `internet_access_allowed = true` — for GuardDuty this takes priority over letting GuardDuty create its own endpoint automatically, which doesn't guarantee correct subnet placement and can fail. All other services must be listed explicitly:

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
| GuardDuty Runtime Monitoring | Security agent event delivery | ~$7 |

*Approximate per AZ in us-east-1*

**Total for all interface endpoints:** ~$14-21/month (depending on AZ count)

**When to disable:**
- Development environments
- Cost-sensitive deployments
- Public subnet architectures

## NAT Gateway vs Public Subnets

### NAT Gateway (Secure)

```hcl
nat_gateways_allowed = true
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
nat_gateways_allowed = false
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
vpc_flow_log_enabled        = true
vpc_flow_log_retention_days = 365
```

**Use cases:**
- Security incident investigation
- Compliance auditing (PCI-DSS, HIPAA)
- Network troubleshooting
- Cost analysis

**Cost:** ~$0.50/GB ingested + storage

## Route53 DNS Firewall

Optional Route 53 Resolver DNS Firewall rule group, associated with this module's dedicated VPC. Not available when using external subnets (`subnets_ids`).

```hcl
dns_firewall_enabled          = true
dns_firewall_advanced_enabled = true # optional, extra option
```

- **AWS managed rules (default)** — blocks/alerts on DNS queries matching the [AWS Managed](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-dns-firewall-managed-domain-lists.html) Aggregate Threat List (malware, ransomware, botnet, spyware, DNS tunneling). AWS Managed Domain List IDs are region-specific and can't be looked up from within Terraform, so this module ships a built-in ID for each commercial region enabled by default — no configuration needed. For a region requiring opt-in, look your ID up once and pass it via `dns_firewall_managed_domain_list_ids`:
  ```sh
  aws route53resolver list-firewall-domain-lists --query "FirewallDomainLists[?ManagedOwnerName=='Route 53 Resolver DNS Firewall']"
  ```
- **DNS Firewall Advanced (extra option)** — set `dns_firewall_advanced_enabled = true` to add rules detecting domain generation algorithm (DGA) and DNS tunneling activity via machine learning, on top of the managed-list rules. Needs no domain list ID.

## IPv6 Support

Dual-stack networking is always enabled — no variable needed. The module automatically assigns:
- VPC IPv6 CIDR block (/56)
- Subnet IPv6 CIDR blocks (/64)
- Egress-only internet gateway
- Route table entries

## Use Cases

- **Microservices** - Service mesh deployments
- **Web Applications** - Public + private tier architecture
- **Data Processing** - Secure data lake infrastructure
- **Compliance Workloads** - HIPAA, PCI-DSS, SOC 2
- **Hybrid Cloud** - VPN/Direct Connect integration
- **Multi-Region** - Consistent VPC architecture

## Requirements

- **AWS Region**: Any region with VPC support

## Best Practices

1. **Use NAT Gateways** for production deployments (enhanced security)
2. **Enable Flow Logs** for compliance auditing and troubleshooting
3. **Deploy VPC Endpoints** to reduce data transfer costs and improve security
4. **Spread across 3 AZs** minimum for high availability
5. **Separate public/private tiers** for defense in depth architecture
6. **Tag all resources** consistently for cost allocation and management

## Security Hub Controls

AWS Security Hub (FSBP / CIS AWS Foundations Benchmark) controls relevant to the resources this module manages:

Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low

| Control | Severity | Title | Status | Options to pass |
|---|---|---|---|---|
| EC2.2 (CIS 5.4) | 🟠 High | VPC default security groups should restrict all traffic | ✅ Pass | `aws_default_security_group` is managed with no ingress/egress blocks, which revokes all default rules. Not configurable; always applied when the module creates the VPC. |
| EC2.6 (CIS 3.9) | 🟡 Medium | VPC flow logging should be enabled in all VPCs | ⚠️ Conditional (default: ✅ Pass) | Keep `vpc_flow_log_enabled = true` (default) to pass. Setting it to `false` fails the control. |
| EC2.15 | 🟡 Medium | EC2 subnets should not automatically assign public IP addresses | ⚠️ Conditional (default: ✅ Pass) | Keep `public_subnets_enabled = false` (default) to pass. Combining `internet_access_allowed = true` with `nat_gateways_allowed = false` fails the control — it makes the **app** subnets public too. |
| EC2.21 (CIS 5.1/5.2) | 🟡 Medium | Network ACLs should not allow ingress from 0.0.0.0/0 to remote administration ports (22, 3389) | ⚠️ Conditional (default: ✅ Pass) | Keep `public_ingress_ports` / `public_to_app_ports` at their defaults (443 / 8000) to pass. Adding an entry with `from_port`/`to_port` covering 22 or 3389 fails the control. |
| EC2.53 / EC2.54 | 🟠 High | Security groups should not allow ingress from 0.0.0.0/0 (IPv4/IPv6) to remote administration ports | ✅ Pass | The module's own security groups never open ingress to 0.0.0.0/0 or ::/0. No option needed; keep any additional security groups attached via `security_group_id` similarly restricted. |
| EC2.13 / EC2.14 | 🟠 High | Security groups should not allow ingress from 0.0.0.0/0 or ::/0 to port 22 / port 3389 | ✅ Pass | Same reasoning as EC2.53/54 — the module's security groups never open port 22 or 3389 to the internet. |
| EC2.12 | 🔵 Low | Unused Amazon EC2 EIPs should be removed | ✅ Pass | The NAT gateway EIP (`aws_eip.netdev_nat`) is always attached to a NAT gateway; never left unused. |
| EC2.37 / EC2.39 / EC2.40 / EC2.41 / EC2.42 / EC2.43 / EC2.44 / EC2.46 / EC2.174 | 🔵 Low | EIP / internet gateway / NAT gateway / network ACL / route table / security group / subnet / VPC / DHCP option set should be tagged | ✅ Pass | Each of these resources is created with `tags = merge(local.tags, {...})`, so it always receives at least a `Name` tag regardless of `var.tags`. |
| EC2.48 | 🔵 Low | Amazon VPC flow logs should be tagged | ⚠️ Conditional (default: ❌ Fail) | Set `tags` to pass. `aws_flow_log.vpc` applies `var.tags` as-is (default `null`), so the flow log ships untagged unless you supply tags. |
| IAM.24 | 🔵 Low | IAM roles should be tagged | ⚠️ Conditional (default: ❌ Fail) | Set `tags` to pass. The VPC flow log IAM role (`aws_iam_role.vpc_flow_log`) applies `var.tags` as-is (default `null`), so it ships untagged unless you supply tags. |
| EC2.55 / EC2.56 / EC2.57 / EC2.58 / EC2.60 | 🟡 Medium | VPCs should be configured with an interface endpoint for ECR API / Docker Registry / Systems Manager / SSM Incident Manager Contacts / SSM Incident Manager | ⚠️ Conditional (default: ❌ Fail) | Set `compliance_vpc_endpoints_enabled = true` (default `false`) with `vpc_endpoints_allowed = true` (default) to pass — together they add the `ecr.api`, `ecr.dkr`, `ssm`, `ssm-contacts` and `ssm-incidents` interface endpoints, enforced regardless of `internet_access_allowed`/`nat_gateways_allowed`. This is opt-in due to the added per-endpoint cost; leave disabled unless these controls are required. Not achievable in the public-subnet architecture (`internet_access_allowed = true` with `nat_gateways_allowed = false`) — no private subnet exists there to host the endpoints. |
| CloudWatch.16 | 🟡 Medium | CloudWatch log groups should be retained for a specified time period (AWS default: ≥365 days) | ⚠️ Conditional (default: ✅ Pass) | Keep `vpc_flow_log_retention_days` at `365` or more (default `365`) to pass. Lowering it fails the control's 365-day default threshold. |

Not mapped to a specific control, but recommended whenever [GuardDuty Runtime Monitoring](https://docs.aws.amazon.com/guardduty/latest/ug/how-does-runtime-monitoring-work.html) is used on resources in this VPC: set `guardduty_vpc_endpoint_enabled = true` (default `false`) to add the `guardduty-data` interface endpoint in this module's own subnets, enforced regardless of `internet_access_allowed`/`nat_gateways_allowed` (same as the compliance endpoints above). This is more reliable than GuardDuty's automated agent configuration, which creates its own endpoint but doesn't guarantee it lands in the right subnets and can fail to provision — enabling this variable takes priority over that automatic creation. Not possible in the public-subnet architecture (`internet_access_allowed = true` with `nat_gateways_allowed = false`) — no private subnet exists there to host it.

Not mapped to a specific control, but recommended as an additional layer of defense: set `dns_firewall_enabled = true` (default `false`) to associate a Route 53 Resolver DNS Firewall rule group with this module's dedicated VPC, blocking DNS queries to domains on an AWS Managed Domain List (via `dns_firewall_managed_domain_list_ids`). Set `dns_firewall_advanced_enabled = true` on top to add DGA and DNS tunneling detection. Only available for the VPC this module creates — not supported with externally-supplied `subnets_ids`.

---

# Terraform Documentation

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.27.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.27.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_app_ipv4_cidr"></a> [app\_ipv4\_cidr](#module\_app\_ipv4\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_app_ipv6_cidr"></a> [app\_ipv6\_cidr](#module\_app\_ipv6\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_kms_key"></a> [kms\_key](#module\_kms\_key) | JGoutin/kms-key/aws | ~> 1.2 |
| <a name="module_netdev_ipv4_cidr"></a> [netdev\_ipv4\_cidr](#module\_netdev\_ipv4\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_netdev_ipv6_cidr"></a> [netdev\_ipv6\_cidr](#module\_netdev\_ipv6\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_public_ipv4_cidr"></a> [public\_ipv4\_cidr](#module\_public\_ipv4\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_public_ipv6_cidr"></a> [public\_ipv6\_cidr](#module\_public\_ipv6\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_vpc_ipv4_cidr"></a> [vpc\_ipv4\_cidr](#module\_vpc\_ipv4\_cidr) | hashicorp/subnets/cidr | n/a |
| <a name="module_vpc_ipv6_cidr"></a> [vpc\_ipv6\_cidr](#module\_vpc\_ipv6\_cidr) | hashicorp/subnets/cidr | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.vpc_flow_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
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
| [aws_route53_resolver_firewall_rule.dns_firewall_advanced](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_firewall_rule) | resource |
| [aws_route53_resolver_firewall_rule.dns_firewall_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_firewall_rule) | resource |
| [aws_route53_resolver_firewall_rule_group.dns_firewall](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_firewall_rule_group) | resource |
| [aws_route53_resolver_firewall_rule_group_association.dns_firewall](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_firewall_rule_group_association) | resource |
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
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_availability_zones_count"></a> [availability\_zones\_count](#input\_availability\_zones\_count) | Maximum count of availability zones to provision with the dedicated VPC. Default to all available availability zones. | `number` | `null` | no |
| <a name="input_compliance_vpc_endpoints_enabled"></a> [compliance\_vpc\_endpoints\_enabled](#input\_compliance\_vpc\_endpoints\_enabled) | If true, add the interface VPC endpoints for ECR API ('ecr.api'), ECR Docker Registry ('ecr.dkr'), Systems Manager ('ssm'), SSM Incident Manager Contacts ('ssm-contacts') and SSM Incident Manager ('ssm-incidents'), on top of any explicitly listed services in var.vpc\_endpoints\_services. Enable only if you have high compliance requirements — each interface endpoint adds cost. Enforced whenever a netdev (private) subnet exists, regardless of var.internet\_access\_allowed/var.nat\_gateways\_allowed; not possible in the public-subnet architecture (var.internet\_access\_allowed=true with var.nat\_gateways\_allowed=false), which has no private subnet to host the endpoints. Ignored if var.vpc\_endpoints\_allowed is false. Security Hub: EC2.55/EC2.56/EC2.57/EC2.58/EC2.60 — default false = fail; set to true to pass. | `bool` | `false` | no |
| <a name="input_dns_firewall_action"></a> [dns\_firewall\_action](#input\_dns\_firewall\_action) | Action taken by DNS Firewall when a query matches a domain from var.dns\_firewall\_managed\_domain\_list\_ids, and (if var.dns\_firewall\_advanced\_enabled) a DNS Firewall Advanced threat detection. Valid values: 'ALLOW', 'BLOCK', 'ALERT'. 'ALLOW' isn't valid for DNS Firewall Advanced rules, so it's treated as 'BLOCK' for those only. Ignored if var.dns\_firewall\_enabled is false. | `string` | `"BLOCK"` | no |
| <a name="input_dns_firewall_advanced_confidence_threshold"></a> [dns\_firewall\_advanced\_confidence\_threshold](#input\_dns\_firewall\_advanced\_confidence\_threshold) | Confidence threshold for DNS Firewall Advanced rules. Valid values: 'LOW', 'MEDIUM', 'HIGH'. Lower thresholds catch more threats at the cost of more false positives. Ignored if var.dns\_firewall\_advanced\_enabled is false. | `string` | `"HIGH"` | no |
| <a name="input_dns_firewall_advanced_enabled"></a> [dns\_firewall\_advanced\_enabled](#input\_dns\_firewall\_advanced\_enabled) | If true, add Route 53 Resolver DNS Firewall Advanced rules blocking DNS queries identified as domain generation algorithm (DGA) or DNS tunneling activity, on top of any managed-domain-list rules. Ignored if var.dns\_firewall\_enabled is false. | `bool` | `false` | no |
| <a name="input_dns_firewall_enabled"></a> [dns\_firewall\_enabled](#input\_dns\_firewall\_enabled) | If true, create a Route 53 Resolver DNS Firewall rule group and associate it with this module's dedicated VPC, blocking/alerting on DNS queries per var.dns\_firewall\_managed\_domain\_lists and var.dns\_firewall\_advanced\_enabled. Only supported for the VPC this module creates; cannot be enabled when using external subnets (subnets\_ids). Not mapped to a Security Hub control; default false = feature not created. | `bool` | `false` | no |
| <a name="input_dns_firewall_managed_domain_list_ids"></a> [dns\_firewall\_managed\_domain\_list\_ids](#input\_dns\_firewall\_managed\_domain\_list\_ids) | Map of AWS Managed Domain List name to ID (e.g. { "AWSManagedDomainsAggregateThreatList" = "rslvr-fdl-..." }) to block/alert on via var.dns\_firewall\_action. Defaults (null) to this module's built-in Aggregate Threat List ID for the current region (see local.dns\_firewall\_default\_managed\_domain\_list\_ids in dns\_firewall.tf), covering commercial regions enabled by default. IDs are region-specific and can't be resolved from within Terraform, so for a region not in that table look yours up with: 'aws route53resolver list-firewall-domain-lists --query "FirewallDomainLists[?ManagedOwnerName=='Route 53 Resolver DNS Firewall']"'. Ignored if var.dns\_firewall\_enabled is false. Set to {} to skip managed-list rules while still using var.dns\_firewall\_advanced\_enabled. | `map(string)` | `null` | no |
| <a name="input_dns_firewall_priority"></a> [dns\_firewall\_priority](#input\_dns\_firewall\_priority) | Processing priority for this module's DNS Firewall rule group association within the VPC (lower is processed first). Must be unique among all rule group associations on the same VPC, including ones created outside this module. Ignored if var.dns\_firewall\_enabled is false. | `number` | `101` | no |
| <a name="input_guardduty_vpc_endpoint_enabled"></a> [guardduty\_vpc\_endpoint\_enabled](#input\_guardduty\_vpc\_endpoint\_enabled) | If true, add the 'guardduty-data' interface VPC endpoint. Only relevant if you use GuardDuty Runtime Monitoring on resources in this VPC — leave false otherwise. Recommended whenever Runtime Monitoring is enabled, even with GuardDuty's automated agent configuration: letting GuardDuty create its own endpoint does not guarantee placement in this module's netdev subnets, and that automatic creation can fail; enabling this takes priority over GuardDuty's own creation and ensures it lands in the correct subnets. Enforced whenever a netdev (private) subnet exists, regardless of var.internet\_access\_allowed/var.nat\_gateways\_allowed — not possible in the public-subnet architecture (var.internet\_access\_allowed=true with var.nat\_gateways\_allowed=false), which has no private subnet to host it. Ignored if var.vpc\_endpoints\_allowed is false. Not mapped to a Security Hub control; default false = endpoint not created. | `bool` | `false` | no |
| <a name="input_internet_access_allowed"></a> [internet\_access\_allowed](#input\_internet\_access\_allowed) | If true, allow internet access. Security Hub: default false = pass for EC2.15 (subnets should not automatically assign public IP addresses); combining true here with var.nat\_gateways\_allowed = false fails EC2.15 by making app subnets public. | `bool` | `false` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | If specified, directly use this KMS key instead of creating a dedicated one for the application. | `string` | `null` | no |
| <a name="input_kms_policy_dependency"></a> [kms\_policy\_dependency](#input\_kms\_policy\_dependency) | To use with 'depends\_on' for resources requiring that KMS policy for key from this module is updated before creation. Only if var.kms\_key\_id is not set. | `list(any)` | `[]` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix to add to all created resources names. | `string` | `"network"` | no |
| <a name="input_nat_gateways_allowed"></a> [nat\_gateways\_allowed](#input\_nat\_gateways\_allowed) | If true, NAT gateways are used to give internet access to the application. If Disabled and internet access is required, application subnets will be public. Disable only if cost is privileged over security. Security Hub: default true avoids the EC2.15 (subnets should not automatically assign public IP addresses) failure mode that occurs when this is false while var.internet\_access\_allowed is true, which makes app subnets public. | `bool` | `true` | no |
| <a name="input_public_ingress_ports"></a> [public\_ingress\_ports](#input\_public\_ingress\_ports) | Map of ports to expose on public subnets from internet. Each entry must specify from\_port. Optional: to\_port (defaults to from\_port), protocol (defaults to 'tcp'). Security Hub: EC2.21 (Network ACLs should not allow ingress from 0.0.0.0/0 to port 22 or port 3389) — default (port 443) = pass; adding an entry with from\_port/to\_port covering 22 or 3389 fails it. | <pre>map(object({<br/>    from_port = number<br/>    to_port   = optional(number)<br/>    protocol  = optional(string, "tcp")<br/>  }))</pre> | <pre>{<br/>  "https": {<br/>    "from_port": 443<br/>  }<br/>}</pre> | no |
| <a name="input_public_subnets_enabled"></a> [public\_subnets\_enabled](#input\_public\_subnets\_enabled) | If true, create public subnets that can access application servers in app subnets. Cannot be used with external subnets (subnets\_ids). Security Hub: default false = pass for EC2.15 (subnets should not automatically assign public IP addresses); enabling this intentionally fails EC2.15 for the public subnet tier only. | `bool` | `false` | no |
| <a name="input_public_to_app_ports"></a> [public\_to\_app\_ports](#input\_public\_to\_app\_ports) | Map of ports for public subnet to app server communication. Each entry must specify from\_port. Optional: to\_port (defaults to from\_port), protocol (defaults to 'tcp'). Security Hub: EC2.21 (Network ACLs should not allow ingress from 0.0.0.0/0 to port 22 or port 3389) — default (port 8000) = pass; adding an entry with from\_port/to\_port covering 22 or 3389 fails it. | <pre>map(object({<br/>    from_port = number<br/>    to_port   = optional(number)<br/>    protocol  = optional(string, "tcp")<br/>  }))</pre> | <pre>{<br/>  "http": {<br/>    "from_port": 8000<br/>  }<br/>}</pre> | no |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | If specified and 'subnet\_ids' is specified, use this security group instead of creating a new one giving access to internet and AWS services. | `string` | `null` | no |
| <a name="input_subnets_ids"></a> [subnets\_ids](#input\_subnets\_ids) | If specified, directly use theses subnets instead of creating a dedicated VPC. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to created resources. Security Hub: most tagging controls (EC2.37/39/40/41/42/43/44/46/174) always pass regardless of this value since a Name tag is always merged in; EC2.48 (VPC flow logs should be tagged) and IAM.24 (IAM roles should be tagged, for the flow log role) apply this value directly with no fallback — default null fails both; set tags to pass. | `map(string)` | `null` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the dedicated VPC. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_endpoints_allowed"></a> [vpc\_endpoints\_allowed](#input\_vpc\_endpoints\_allowed) | If true, VPC endpoints interfaces are privileged to give AWS services access to the application if no internet access is required. VPC endpoint Gateway are always provisioned. Disable only if cost is privileged over security. Security Hub: must be true for var.compliance\_vpc\_endpoints\_enabled and var.guardduty\_vpc\_endpoint\_enabled to take effect. | `bool` | `true` | no |
| <a name="input_vpc_endpoints_services"></a> [vpc\_endpoints\_services](#input\_vpc\_endpoints\_services) | List of AWS services endpoints to give access to the application. See also var.compliance\_vpc\_endpoints\_enabled and var.guardduty\_vpc\_endpoint\_enabled, which extend this list automatically. | `list(string)` | `[]` | no |
| <a name="input_vpc_flow_log_enabled"></a> [vpc\_flow\_log\_enabled](#input\_vpc\_flow\_log\_enabled) | If true, enable VPC flow log. Security Hub: EC2.6 (VPC flow logging should be enabled in all VPCs) — default true = pass; setting false fails this control. | `bool` | `true` | no |
| <a name="input_vpc_flow_log_retention_days"></a> [vpc\_flow\_log\_retention\_days](#input\_vpc\_flow\_log\_retention\_days) | VPC flow log retention days. Security Hub: CloudWatch.16 (CloudWatch log groups should be retained for a specified time period) requires at least 365 days by default — default 365 = pass; lowering it fails this control. | `number` | `365` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dns_firewall_rule_group_id"></a> [dns\_firewall\_rule\_group\_id](#output\_dns\_firewall\_rule\_group\_id) | Route 53 Resolver DNS Firewall rule group ID. Null if var.dns\_firewall\_enabled is false. |
| <a name="output_ipv6_enabled"></a> [ipv6\_enabled](#output\_ipv6\_enabled) | Whether IPv6 is enabled on the VPC. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | KMS key ARN. |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | KMS key ID. |
| <a name="output_kms_policy_dependency"></a> [kms\_policy\_dependency](#output\_kms\_policy\_dependency) | To use with 'depends\_on' for resources requiring that KMS policy is updated before creation. Only if var.kms\_key\_id is set. |
| <a name="output_kms_policy_documents_json"></a> [kms\_policy\_documents\_json](#output\_kms\_policy\_documents\_json) | KMS policy documents to add to the policy of the key specified via var.kms\_key\_id. |
| <a name="output_public_subnets_ids"></a> [public\_subnets\_ids](#output\_public\_subnets\_ids) | Public subnets IDs. Empty list if public subnets are not enabled. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security groups ID. |
| <a name="output_subnets_ids"></a> [subnets\_ids](#output\_subnets\_ids) | Subnets ID. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID. |
<!-- END_TF_DOCS -->
