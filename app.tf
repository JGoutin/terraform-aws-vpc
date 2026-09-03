/*
Application subnet & security group configuration
*/

locals {
  subnet_ids            = local.vpc_enabled ? [for az in local.vpc_availability_zones : aws_subnet.app[az].id] : var.subnets_ids
  vpc_id                = local.vpc_enabled ? aws_vpc.vpc[0].id : data.aws_subnet.app[0].vpc_id
  security_group_id     = local.security_group_create ? aws_security_group.app[0].id : var.security_group_id
  security_group_create = local.vpc_enabled || (var.security_group_id == null)
}

# Application base security group

resource "aws_security_group" "app" {
  count       = local.security_group_create ? 1 : 0
  name        = "${var.name_prefix}-app-sg-${local.region}"
  description = "Security group for ${var.name_prefix} application"
  vpc_id      = local.vpc_id
  egress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = (local.internet_required || !local.vpc_enabled) ? ["0.0.0.0/0"] : null
    ipv6_cidr_blocks = (local.internet_required || !local.vpc_enabled) ? ["::/0"] : null
    prefix_list_ids  = local.vpce_interfaces_enabled ? [for gateway in values(aws_vpc_endpoint.netdev_vpce_gateway) : gateway.prefix_list_id] : null
    security_groups  = local.vpce_interfaces_enabled ? [aws_security_group.netdev_vpce[0].id] : null
  }
  tags = merge(local.tags, { Name = "${var.name_prefix}-app-sg-${local.region}" })
}

# Subnets

locals {
  # NACL rules for app subnets - ingress from public subnets
  app_nacl_rules_from_public_ipv4 = local.public_subnets_enabled ? flatten([
    for k, v in var.public_to_app_ports : [
      {
        cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["public"]
        from_port  = v.from_port
        to_port    = coalesce(v.to_port, v.from_port)
        protocol   = v.protocol
      }
    ]
  ]) : []

  app_nacl_rules_from_public_ipv6 = local.public_subnets_enabled ? flatten([
    for k, v in var.public_to_app_ports : [
      {
        cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["public"]
        from_port  = v.from_port
        to_port    = coalesce(v.to_port, v.from_port)
        protocol   = v.protocol
      }
    ]
  ]) : []

  # NACL rules for app subnets - egress to public subnets (ephemeral ports)
  app_nacl_rules_to_public_ipv4 = local.public_subnets_enabled ? flatten([
    for k, v in var.public_to_app_ports : [
      {
        cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["public"]
        from_port  = 1024
        to_port    = 65535
        protocol   = v.protocol
      }
    ]
  ]) : []

  app_nacl_rules_to_public_ipv6 = local.public_subnets_enabled ? flatten([
    for k, v in var.public_to_app_ports : [
      {
        cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["public"]
        from_port  = 1024
        to_port    = 65535
        protocol   = v.protocol
      }
    ]
  ]) : []

  # NACL rules for app subnets - allow all intra-app traffic
  app_nacl_rules_intra_ipv4 = local.vpc_enabled ? [
    {
      cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["app"]
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
    }
  ] : []

  app_nacl_rules_intra_ipv6 = local.vpc_enabled ? [
    {
      cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["app"]
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
    }
  ] : []

  # NACL rules for app subnets - extra internet flows requested by the caller
  # A network ACL is stateless: each requested flow also opens its reply direction on the
  # ephemeral range, which is where the other end answers. That reply rule only depends on the
  # protocol, so entries sharing one would emit the same rule twice: distinct keeps a single copy
  # and spares the 20-rules-per-direction quota.
  app_nacl_rules_internet_ipv4_ingress = local.internet_required ? concat(
    [for k, v in var.internet_to_app_ports : { cidr_block = "0.0.0.0/0", from_port = v.from_port, to_port = coalesce(v.to_port, v.from_port), protocol = v.protocol }],
    distinct([for k, v in var.app_to_internet_ports : { cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535, protocol = v.protocol }]),
  ) : []

  app_nacl_rules_internet_ipv4_egress = local.internet_required ? concat(
    distinct([for k, v in var.internet_to_app_ports : { cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535, protocol = v.protocol }]),
    [for k, v in var.app_to_internet_ports : { cidr_block = "0.0.0.0/0", from_port = v.from_port, to_port = coalesce(v.to_port, v.from_port), protocol = v.protocol }],
  ) : []

  app_nacl_rules_internet_ipv6_ingress = local.internet_required ? concat(
    [for k, v in var.internet_to_app_ports : { cidr_block = "::/0", from_port = v.from_port, to_port = coalesce(v.to_port, v.from_port), protocol = v.protocol }],
    distinct([for k, v in var.app_to_internet_ports : { cidr_block = "::/0", from_port = 1024, to_port = 65535, protocol = v.protocol }]),
  ) : []

  app_nacl_rules_internet_ipv6_egress = local.internet_required ? concat(
    distinct([for k, v in var.internet_to_app_ports : { cidr_block = "::/0", from_port = 1024, to_port = 65535, protocol = v.protocol }]),
    [for k, v in var.app_to_internet_ports : { cidr_block = "::/0", from_port = v.from_port, to_port = coalesce(v.to_port, v.from_port), protocol = v.protocol }],
  ) : []

  # NACL rules
  # netdev and internet access are independent, not exclusive: both rules are added whenever needed.
  # Caller-requested flows come last: rule numbers are index-based (401 for IPv4, 601 for IPv6),
  # so appending leaves every existing number untouched, and IPv4 keeps 200 free slots below the
  # IPv6 base - far more than the number of rules a network ACL accepts.
  app_nacl_rules_ipv4_ingress = concat(
    local.app_nacl_rules_intra_ipv4,
    local.vpce_interfaces_enabled ? [
      # Allow responses from devices subnets
      { cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["netdev"], from_port = 1024, to_port = 65535, protocol = "tcp" },
    ] : [],
    local.internet_required ? [
      # Allow responses from internet
      { cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535, protocol = "tcp" }
    ] : [],
    local.app_nacl_rules_from_public_ipv4,
    local.app_nacl_rules_internet_ipv4_ingress
  )
  app_nacl_rules_ipv4_egress = concat(
    local.app_nacl_rules_intra_ipv4,
    local.vpce_interfaces_enabled ? [
      # Allow requests to devices subnets
      { cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["netdev"], from_port = 443, to_port = 443, protocol = "tcp" },
    ] : [],
    local.internet_required ? [
      # Allow requests to internet
      { cidr_block = "0.0.0.0/0", from_port = 443, to_port = 443, protocol = "tcp" }
    ] : [],
    local.app_nacl_rules_to_public_ipv4,
    local.app_nacl_rules_internet_ipv4_egress
  )
  app_nacl_rules_ipv6_ingress = concat(
    local.app_nacl_rules_intra_ipv6,
    local.vpce_interfaces_enabled ? [
      # Allow responses from devices subnets
      { cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["netdev"], from_port = 1024, to_port = 65535, protocol = "tcp" },
    ] : [],
    local.internet_required ? [
      # Allow responses from internet (direct or via NAT Gateway)
      { cidr_block = "::/0", from_port = 1024, to_port = 65535, protocol = "tcp" },
    ] : [],
    local.app_nacl_rules_from_public_ipv6,
    local.app_nacl_rules_internet_ipv6_ingress
  )
  app_nacl_rules_ipv6_egress = concat(
    local.app_nacl_rules_intra_ipv6,
    local.vpce_interfaces_enabled ? [
      # Allow requests to devices subnets
      { cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["netdev"], from_port = 443, to_port = 443, protocol = "tcp" },
    ] : [],
    local.internet_required ? [
      # Allow requests to internet (direct or via NAT Gateway)
      { cidr_block = "::/0", from_port = 443, to_port = 443, protocol = "tcp" },
    ] : [],
    local.app_nacl_rules_to_public_ipv6,
    local.app_nacl_rules_internet_ipv6_egress
  )
}

module "app_ipv4_cidr" {
  source          = "hashicorp/subnets/cidr"
  count           = local.vpc_resource_count
  base_cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["app"] # /19
  networks = [for az in local.vpc_availability_zones : {
    name     = az
    new_bits = 5 # /24 (256 IPs per subnet, supports up to 8 AZs)
  }]
}

module "app_ipv6_cidr" {
  source          = "hashicorp/subnets/cidr"
  count           = local.vpc_resource_count
  base_cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["app"] # /61
  networks = [for az in local.vpc_availability_zones : {
    name     = az
    new_bits = 3 # /64 (supports up to 8 AZs)
  }]
}

resource "aws_subnet" "app" {
  for_each                        = local.vpc_availability_zones
  vpc_id                          = aws_vpc.vpc[0].id
  availability_zone               = each.key
  cidr_block                      = module.app_ipv4_cidr[0].network_cidr_blocks[each.key]
  ipv6_cidr_block                 = module.app_ipv6_cidr[0].network_cidr_blocks[each.key]
  assign_ipv6_address_on_creation = true
  # Public in the no-NAT architecture, but still not handing out addresses:
  # what runs here is an ECS task, which takes its public address from
  # "assign_public_ip" on its own network configuration. See the public subnet.
  map_public_ip_on_launch = false
  tags                    = merge(local.tags, { Name = "${var.name_prefix}-app-sn-${each.key}" })
}

resource "aws_route_table" "app" {
  for_each = local.vpc_availability_zones
  vpc_id   = aws_vpc.vpc[0].id
  tags     = merge(local.tags, { Name = "${var.name_prefix}-app-rt-${each.key}" })
}

resource "aws_route_table_association" "app" {
  for_each       = local.vpc_availability_zones
  subnet_id      = aws_subnet.app[each.key].id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_network_acl" "app" {
  count  = local.vpc_enabled ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id
  tags   = merge(local.tags, { Name = "${var.name_prefix}-app-nacl-${local.region}" })
}

resource "aws_network_acl_association" "app" {
  for_each       = local.vpc_availability_zones
  network_acl_id = aws_network_acl.app[0].id
  subnet_id      = aws_subnet.app[each.key].id
}

resource "aws_network_acl_rule" "app_ipv4_ingress" {
  count          = local.vpc_enabled ? length(local.app_nacl_rules_ipv4_ingress) : 0
  network_acl_id = aws_network_acl.app[0].id
  rule_number    = 401 + count.index
  egress         = false
  protocol       = local.app_nacl_rules_ipv4_ingress[count.index].protocol
  rule_action    = "allow"
  cidr_block     = local.app_nacl_rules_ipv4_ingress[count.index].cidr_block
  from_port      = local.app_nacl_rules_ipv4_ingress[count.index].from_port
  to_port        = local.app_nacl_rules_ipv4_ingress[count.index].to_port
}

resource "aws_network_acl_rule" "app_ipv4_egress" {
  count          = local.vpc_enabled ? length(local.app_nacl_rules_ipv4_egress) : 0
  network_acl_id = aws_network_acl.app[0].id
  rule_number    = 401 + count.index
  egress         = true
  protocol       = local.app_nacl_rules_ipv4_egress[count.index].protocol
  rule_action    = "allow"
  cidr_block     = local.app_nacl_rules_ipv4_egress[count.index].cidr_block
  from_port      = local.app_nacl_rules_ipv4_egress[count.index].from_port
  to_port        = local.app_nacl_rules_ipv4_egress[count.index].to_port
}

resource "aws_network_acl_rule" "app_ipv6_ingress" {
  count           = local.vpc_enabled ? length(local.app_nacl_rules_ipv6_ingress) : 0
  network_acl_id  = aws_network_acl.app[0].id
  rule_number     = 601 + count.index
  egress          = false
  protocol        = local.app_nacl_rules_ipv6_ingress[count.index].protocol
  rule_action     = "allow"
  ipv6_cidr_block = local.app_nacl_rules_ipv6_ingress[count.index].cidr_block
  from_port       = local.app_nacl_rules_ipv6_ingress[count.index].from_port
  to_port         = local.app_nacl_rules_ipv6_ingress[count.index].to_port
}

resource "aws_network_acl_rule" "app_ipv6_egress" {
  count           = local.vpc_enabled ? length(local.app_nacl_rules_ipv6_egress) : 0
  network_acl_id  = aws_network_acl.app[0].id
  rule_number     = 601 + count.index
  egress          = true
  protocol        = local.app_nacl_rules_ipv6_egress[count.index].protocol
  rule_action     = "allow"
  ipv6_cidr_block = local.app_nacl_rules_ipv6_egress[count.index].cidr_block
  from_port       = local.app_nacl_rules_ipv6_egress[count.index].from_port
  to_port         = local.app_nacl_rules_ipv6_egress[count.index].to_port
}

# Existing user provided subnets

data "aws_subnet" "app" {
  count = local.vpc_enabled ? 0 : 1
  id    = var.subnets_ids[0]
}

# All externally-provided subnets, looked up to expose their CIDR blocks.
# Keyed by position: the subnet IDs may be unknown at plan time, their count is not.
data "aws_subnet" "provided" {
  for_each = local.vpc_enabled ? {} : { for i, id in var.subnets_ids : format("%03d", i) => id }
  id       = each.value
}
