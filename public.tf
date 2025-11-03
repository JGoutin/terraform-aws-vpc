/*
Public subnets configuration
*/

locals {
  public_subnets_enabled    = var.public_subnets_enabled && local.vpc_enabled
  public_availability_zones = toset(local.public_subnets_enabled ? local.vpc_availability_zones : [])

  # Calculate ephemeral port ranges based on protocols
  ephemeral_tcp_ports = {
    from_port = 1024
    to_port   = 65535
    protocol  = "tcp"
  }
  ephemeral_udp_ports = {
    from_port = 1024
    to_port   = 65535
    protocol  = "udp"
  }

  # Collect unique protocols from both ingress and app port configs
  protocols_used = toset(concat(
    [for k, v in var.public_ingress_ports : v.protocol],
    [for k, v in var.public_to_app_ports : v.protocol]
  ))

  # NACL rules for public subnets
  # Ingress: Allow public ingress ports from internet
  public_nacl_ipv4_ingress_public = [
    for k, v in var.public_ingress_ports : {
      cidr_block = "0.0.0.0/0"
      from_port  = v.from_port
      to_port    = coalesce(v.to_port, v.from_port)
      protocol   = v.protocol
    }
  ]

  # Ingress: Allow ephemeral ports for return traffic
  public_nacl_ipv4_ingress_ephemeral = [
    for protocol in local.protocols_used : {
      cidr_block = "0.0.0.0/0"
      from_port  = protocol == "tcp" ? local.ephemeral_tcp_ports.from_port : local.ephemeral_udp_ports.from_port
      to_port    = protocol == "tcp" ? local.ephemeral_tcp_ports.to_port : local.ephemeral_udp_ports.to_port
      protocol   = protocol
    }
  ]

  # Ingress: Allow return traffic from app subnets
  public_nacl_ipv4_ingress_app_return = local.public_subnets_enabled ? [
    for k, v in var.public_to_app_ports : {
      cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["app"]
      from_port  = local.ephemeral_tcp_ports.from_port
      to_port    = local.ephemeral_tcp_ports.to_port
      protocol   = v.protocol
    }
  ] : []

  # Egress: Allow traffic to app subnets on configured ports
  public_nacl_ipv4_egress_to_app = local.public_subnets_enabled ? [
    for k, v in var.public_to_app_ports : {
      cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["app"]
      from_port  = v.from_port
      to_port    = coalesce(v.to_port, v.from_port)
      protocol   = v.protocol
    }
  ] : []

  # Egress: Allow ephemeral response ports to internet
  public_nacl_ipv4_egress_ephemeral = [
    for protocol in local.protocols_used : {
      cidr_block = "0.0.0.0/0"
      from_port  = protocol == "tcp" ? local.ephemeral_tcp_ports.from_port : local.ephemeral_udp_ports.from_port
      to_port    = protocol == "tcp" ? local.ephemeral_tcp_ports.to_port : local.ephemeral_udp_ports.to_port
      protocol   = protocol
    }
  ]

  # Combine all NACL rules
  public_nacl_rules_ipv4_ingress = local.public_subnets_enabled ? concat(
    local.public_nacl_ipv4_ingress_public,
    local.public_nacl_ipv4_ingress_ephemeral,
    local.public_nacl_ipv4_ingress_app_return
  ) : []

  public_nacl_rules_ipv4_egress = local.public_subnets_enabled ? concat(
    local.public_nacl_ipv4_egress_to_app,
    local.public_nacl_ipv4_egress_ephemeral
  ) : []

  # IPv6 rules - similar structure
  public_nacl_ipv6_ingress_public = [
    for k, v in var.public_ingress_ports : {
      cidr_block = "::/0"
      from_port  = v.from_port
      to_port    = coalesce(v.to_port, v.from_port)
      protocol   = v.protocol
    }
  ]

  public_nacl_ipv6_ingress_ephemeral = [
    for protocol in local.protocols_used : {
      cidr_block = "::/0"
      from_port  = protocol == "tcp" ? local.ephemeral_tcp_ports.from_port : local.ephemeral_udp_ports.from_port
      to_port    = protocol == "tcp" ? local.ephemeral_tcp_ports.to_port : local.ephemeral_udp_ports.to_port
      protocol   = protocol
    }
  ]

  public_nacl_ipv6_ingress_app_return = local.public_subnets_enabled ? [
    for k, v in var.public_to_app_ports : {
      cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["app"]
      from_port  = local.ephemeral_tcp_ports.from_port
      to_port    = local.ephemeral_tcp_ports.to_port
      protocol   = v.protocol
    }
  ] : []

  public_nacl_ipv6_egress_to_app = local.public_subnets_enabled ? [
    for k, v in var.public_to_app_ports : {
      cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["app"]
      from_port  = v.from_port
      to_port    = coalesce(v.to_port, v.from_port)
      protocol   = v.protocol
    }
  ] : []

  public_nacl_ipv6_egress_ephemeral = [
    for protocol in local.protocols_used : {
      cidr_block = "::/0"
      from_port  = protocol == "tcp" ? local.ephemeral_tcp_ports.from_port : local.ephemeral_udp_ports.from_port
      to_port    = protocol == "tcp" ? local.ephemeral_tcp_ports.to_port : local.ephemeral_udp_ports.to_port
      protocol   = protocol
    }
  ]

  public_nacl_rules_ipv6_ingress = local.public_subnets_enabled ? concat(
    local.public_nacl_ipv6_ingress_public,
    local.public_nacl_ipv6_ingress_ephemeral,
    local.public_nacl_ipv6_ingress_app_return
  ) : []

  public_nacl_rules_ipv6_egress = local.public_subnets_enabled ? concat(
    local.public_nacl_ipv6_egress_to_app,
    local.public_nacl_ipv6_egress_ephemeral
  ) : []
}

# CIDR blocks for public subnets

module "public_ipv4_cidr" {
  source          = "hashicorp/subnets/cidr"
  count           = local.public_subnets_enabled ? 1 : 0
  base_cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["public"] # /19
  networks = [for az in local.vpc_availability_zones : {
    name     = az
    new_bits = 5 # /24 (256 IPs per subnet, supports up to 8 AZs)
  }]
}

module "public_ipv6_cidr" {
  source          = "hashicorp/subnets/cidr"
  count           = local.public_subnets_enabled ? 1 : 0
  base_cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["public"] # /61
  networks = [for az in local.vpc_availability_zones : {
    name     = az
    new_bits = 3 # /64 (supports up to 8 AZs)
  }]
}

# Public subnets

resource "aws_subnet" "public" {
  for_each                        = local.public_availability_zones
  vpc_id                          = aws_vpc.vpc[0].id
  availability_zone               = each.key
  cidr_block                      = module.public_ipv4_cidr[0].network_cidr_blocks[each.key]
  ipv6_cidr_block                 = module.public_ipv6_cidr[0].network_cidr_blocks[each.key]
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = true
  tags                            = { Name = "${var.name_prefix}-public-sn-${each.key}" }
}

resource "aws_route_table" "public" {
  count  = local.public_subnets_enabled ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id
  tags   = { Name = "${var.name_prefix}-public-rt-${local.region}" }
}

resource "aws_route_table_association" "public" {
  for_each       = local.public_availability_zones
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[0].id
}

# Routes to internet

resource "aws_route" "public_to_internet_ipv4" {
  count                  = local.public_subnets_enabled ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.netdev[0].id
}

resource "aws_route" "public_to_internet_ipv6" {
  count                       = local.public_subnets_enabled ? 1 : 0
  route_table_id              = aws_route_table.public[0].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.netdev[0].id
}

# Network ACLs

resource "aws_network_acl" "public" {
  count  = local.public_subnets_enabled ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id
  tags   = { Name = "${var.name_prefix}-public-nacl-${local.region}" }
}

resource "aws_network_acl_association" "public" {
  for_each       = local.public_availability_zones
  network_acl_id = aws_network_acl.public[0].id
  subnet_id      = aws_subnet.public[each.key].id
}

# IPv4 NACL rules

resource "aws_network_acl_rule" "public_ipv4_ingress" {
  count          = length(local.public_nacl_rules_ipv4_ingress)
  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 100 + count.index
  egress         = false
  protocol       = local.public_nacl_rules_ipv4_ingress[count.index].protocol
  rule_action    = "allow"
  cidr_block     = local.public_nacl_rules_ipv4_ingress[count.index].cidr_block
  from_port      = local.public_nacl_rules_ipv4_ingress[count.index].from_port
  to_port        = local.public_nacl_rules_ipv4_ingress[count.index].to_port
}

resource "aws_network_acl_rule" "public_ipv4_egress" {
  count          = length(local.public_nacl_rules_ipv4_egress)
  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 100 + count.index
  egress         = true
  protocol       = local.public_nacl_rules_ipv4_egress[count.index].protocol
  rule_action    = "allow"
  cidr_block     = local.public_nacl_rules_ipv4_egress[count.index].cidr_block
  from_port      = local.public_nacl_rules_ipv4_egress[count.index].from_port
  to_port        = local.public_nacl_rules_ipv4_egress[count.index].to_port
}

# IPv6 NACL rules

resource "aws_network_acl_rule" "public_ipv6_ingress" {
  count           = length(local.public_nacl_rules_ipv6_ingress)
  network_acl_id  = aws_network_acl.public[0].id
  rule_number     = 200 + count.index
  egress          = false
  protocol        = local.public_nacl_rules_ipv6_ingress[count.index].protocol
  rule_action     = "allow"
  ipv6_cidr_block = local.public_nacl_rules_ipv6_ingress[count.index].cidr_block
  from_port       = local.public_nacl_rules_ipv6_ingress[count.index].from_port
  to_port         = local.public_nacl_rules_ipv6_ingress[count.index].to_port
}

resource "aws_network_acl_rule" "public_ipv6_egress" {
  count           = length(local.public_nacl_rules_ipv6_egress)
  network_acl_id  = aws_network_acl.public[0].id
  rule_number     = 200 + count.index
  egress          = true
  protocol        = local.public_nacl_rules_ipv6_egress[count.index].protocol
  rule_action     = "allow"
  ipv6_cidr_block = local.public_nacl_rules_ipv6_egress[count.index].cidr_block
  from_port       = local.public_nacl_rules_ipv6_egress[count.index].from_port
  to_port         = local.public_nacl_rules_ipv6_egress[count.index].to_port
}
