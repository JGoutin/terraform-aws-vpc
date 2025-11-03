/*
Network devices
*/

# Network devices subnets

locals {
  netdev_availability_zones = toset(local.public_subnet_enabled ? [] : local.vpc_availability_zones)

  # NACL rules
  netdev_nacl_rules_ipv4_ingress = local.vpc_enabled && !local.public_subnet_enabled ? concat([
    # Allow requests from main subnets
    { cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["app"], from_port = 443, to_port = 443 },
    ], local.nat_gateways_enabled ? [
    # Allow responses from internet
    { cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535 }
  ] : []) : []
  netdev_nacl_rules_ipv4_egress = local.vpc_enabled && !local.public_subnet_enabled ? concat([
    # Allow responses from main subnets
    { cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["app"], from_port = 1024, to_port = 65535 },
    ], local.nat_gateways_enabled ? [
    # Allow requests to internet
    { cidr_block = "0.0.0.0/0", from_port = 443, to_port = 443 }
  ] : []) : []
  netdev_nacl_rules_ipv6_ingress = local.vpce_interfaces_enabled ? [
    # Allow requests from main subnets
    { cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["app"], from_port = 443, to_port = 443 },
  ] : []
  netdev_nacl_rules_ipv6_egress = local.vpce_interfaces_enabled ? [
    # Allow responses from main subnets
    { cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["app"], from_port = 1024, to_port = 65535 },
  ] : []
}

module "netdev_ipv4_cidr" {
  source          = "hashicorp/subnets/cidr"
  count           = local.vpc_enabled && !local.public_subnet_enabled ? 1 : 0
  base_cidr_block = module.vpc_ipv4_cidr[0].network_cidr_blocks["netdev"] # /19
  networks = [for az in local.vpc_availability_zones : {
    name     = az
    new_bits = 5 # /24 (256 IPs per subnet, supports up to 8 AZs)
  }]
}

module "netdev_ipv6_cidr" {
  source          = "hashicorp/subnets/cidr"
  count           = local.vpc_enabled && !local.public_subnet_enabled ? 1 : 0
  base_cidr_block = module.vpc_ipv6_cidr[0].network_cidr_blocks["netdev"] # /61
  networks = [for az in local.vpc_availability_zones : {
    name     = az
    new_bits = 3 # /64 (supports up to 8 AZs)
  }]
}

resource "aws_subnet" "netdev" {
  for_each                        = local.netdev_availability_zones
  vpc_id                          = aws_vpc.vpc[0].id
  availability_zone               = each.key
  cidr_block                      = module.netdev_ipv4_cidr[0].network_cidr_blocks[each.key]
  ipv6_cidr_block                 = module.netdev_ipv6_cidr[0].network_cidr_blocks[each.key]
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = false
  tags                            = { Name = "${var.name_prefix}-netdev-sn-${each.key}" }
}

resource "aws_route_table" "netdev" {
  count  = local.vpc_enabled && !local.public_subnet_enabled ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id
  tags   = { Name = "${var.name_prefix}-netdev-rt-${local.region}" }
}

resource "aws_route_table_association" "netdev" {
  for_each       = local.netdev_availability_zones
  subnet_id      = aws_subnet.netdev[each.key].id
  route_table_id = aws_route_table.netdev[0].id
}

resource "aws_network_acl" "netdev" {
  count  = local.vpc_enabled && !local.public_subnet_enabled ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id
  tags   = { Name = "${var.name_prefix}-netdev-nacl-${local.region}" }
}

resource "aws_network_acl_association" "netdev" {
  for_each       = local.netdev_availability_zones
  network_acl_id = aws_network_acl.netdev[0].id
  subnet_id      = aws_subnet.netdev[each.key].id
}

resource "aws_network_acl_rule" "netdev_ipv4_ingress" {
  count          = length(local.netdev_nacl_rules_ipv4_ingress)
  network_acl_id = aws_network_acl.netdev[0].id
  rule_number    = 401 + count.index
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = local.netdev_nacl_rules_ipv4_ingress[count.index].cidr_block
  from_port      = local.netdev_nacl_rules_ipv4_ingress[count.index].from_port
  to_port        = local.netdev_nacl_rules_ipv4_ingress[count.index].to_port
}

resource "aws_network_acl_rule" "netdev_ipv4_egress" {
  count          = length(local.netdev_nacl_rules_ipv4_egress)
  network_acl_id = aws_network_acl.netdev[0].id
  rule_number    = 401 + count.index
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = local.netdev_nacl_rules_ipv4_egress[count.index].cidr_block
  from_port      = local.netdev_nacl_rules_ipv4_egress[count.index].from_port
  to_port        = local.netdev_nacl_rules_ipv4_egress[count.index].to_port
}

resource "aws_network_acl_rule" "netdev_ipv6_ingress" {
  count           = length(local.netdev_nacl_rules_ipv6_ingress)
  network_acl_id  = aws_network_acl.netdev[0].id
  rule_number     = 601 + count.index
  egress          = false
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = local.netdev_nacl_rules_ipv6_ingress[count.index].cidr_block
  from_port       = local.netdev_nacl_rules_ipv6_ingress[count.index].from_port
  to_port         = local.netdev_nacl_rules_ipv6_ingress[count.index].to_port
}

resource "aws_network_acl_rule" "netdev_ipv6_egress" {
  count           = length(local.netdev_nacl_rules_ipv6_egress)
  network_acl_id  = aws_network_acl.netdev[0].id
  rule_number     = 601 + count.index
  egress          = true
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = local.netdev_nacl_rules_ipv6_egress[count.index].cidr_block
  from_port       = local.netdev_nacl_rules_ipv6_egress[count.index].from_port
  to_port         = local.netdev_nacl_rules_ipv6_egress[count.index].to_port
}

# Network devices : VPC endpoints

resource "aws_vpc_endpoint" "netdev_vpce_gateway" {
  for_each          = local.vpc_enabled ? local.vpce_gateway_services : []
  vpc_id            = aws_vpc.vpc[0].id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type = "Gateway"
  tags              = { Name = "${var.name_prefix}-vpce-${each.key}-${local.region}" }
}

resource "aws_vpc_endpoint_route_table_association" "netdev_app_to_vpce" {
  for_each = {
    for v in setproduct(keys(aws_vpc_endpoint.netdev_vpce_gateway), local.vpc_availability_zones) :
    "${v[0]}.${v[1]}" => {
      service           = v[0]
      availability_zone = v[1]
    }
  }
  route_table_id  = aws_route_table.app[each.value.availability_zone].id
  vpc_endpoint_id = aws_vpc_endpoint.netdev_vpce_gateway[each.value.service].id
}

resource "aws_vpc_endpoint" "netdev_vpce_interface" {
  for_each            = local.vpc_enabled ? data.aws_vpc_endpoint_service.netdev_vpce_interface : {}
  vpc_id              = aws_vpc.vpc[0].id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  ip_address_type     = contains(each.value.supported_ip_address_types, "ipv6") ? "dualstack" : "ipv4"
  subnet_ids          = [for az in local.vpc_availability_zones : aws_subnet.netdev[az].id]
  security_group_ids  = [aws_security_group.netdev_vpce[0].id]
  private_dns_enabled = true
  tags                = { Name = "${var.name_prefix}-vpce-${each.key}-${local.region}" }
  dns_options {
    dns_record_ip_type = contains(each.value.supported_ip_address_types, "ipv6") ? "dualstack" : "ipv4"
  }
}

data "aws_vpc_endpoint_service" "netdev_vpce_interface" {
  for_each     = toset(local.vpce_interfaces_enabled ? local.vpce_interfaces_services : [])
  service      = each.key
  service_type = "Interface"
}

resource "aws_security_group" "netdev_vpce" {
  count       = local.vpce_interfaces_enabled && local.vpc_enabled ? 1 : 0
  name        = "${var.name_prefix}-vpce-sg-${local.region}"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.vpc[0].id
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [module.vpc_ipv4_cidr[0].network_cidr_blocks["app"]]
    ipv6_cidr_blocks = [module.vpc_ipv6_cidr[0].network_cidr_blocks["app"]]
  }
  tags = { Name = "${var.name_prefix}-vpce-sg-${local.region}" }
}

# Network devices : Internet Gateways

resource "aws_internet_gateway" "netdev" {
  count  = local.vpc_enabled && local.internet_required ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id
  tags   = { Name = "${var.name_prefix}-igw-${local.region}" }
}

resource "aws_egress_only_internet_gateway" "netdev" {
  count  = local.vpc_enabled && local.internet_required ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id
  tags   = { Name = "${var.name_prefix}-eigw-${local.region}" }
}

resource "aws_route" "netdev_app_to_web_ipv6" {
  for_each                    = toset(local.vpc_enabled && local.internet_required ? local.vpc_availability_zones : [])
  route_table_id              = aws_route_table.app[each.key].id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.netdev[0].id
}

resource "aws_route" "netdev_app_to_web_ipv4" {
  for_each               = toset(local.vpc_enabled && local.public_subnet_enabled ? local.vpc_availability_zones : [])
  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.netdev[0].id
}

# Network devices : NAT Gateways

resource "aws_nat_gateway" "netdev_nat" {
  for_each      = toset(local.vpc_enabled && local.nat_gateways_enabled ? local.vpc_availability_zones : [])
  allocation_id = aws_eip.netdev_nat[each.key].id
  subnet_id     = aws_subnet.netdev[each.key].id
  tags          = { Name = "${var.name_prefix}-natgw-${each.key}" }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "netdev_nat" {
  for_each = toset(local.vpc_enabled && local.nat_gateways_enabled ? local.vpc_availability_zones : [])
  tags     = { Name = "${var.name_prefix}-natgw-eip-${each.key}" }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route" "netdev_app_to_nat_ipv4" {
  for_each               = toset(local.vpc_enabled && local.nat_gateways_enabled ? local.vpc_availability_zones : [])
  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.netdev_nat[each.key].id
}

resource "aws_route" "netdev_nat_to_web_ipv4" {
  count                  = local.vpc_enabled && local.nat_gateways_enabled ? 1 : 0
  route_table_id         = aws_route_table.netdev[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.netdev[0].id
}
