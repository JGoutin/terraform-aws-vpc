/*
VPC globale configuration
*/

resource "aws_vpc" "vpc" {
  count                            = local.vpc_resource_count
  cidr_block                       = var.vpc_cidr
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true
  tags                             = { Name = "${var.name_prefix}-vpc-${local.region}" }
}

resource "aws_vpc_dhcp_options" "vpc" {
  count               = local.vpc_resource_count
  domain_name_servers = ["AmazonProvidedDNS"]
  ntp_servers         = ["169.254.169.123", "fd00:ec2::123"] # AWS NTP server (IPv4 and IPv6)
  tags                = { Name = "${var.name_prefix}-dhcpo-${local.region}" }
}

resource "aws_vpc_dhcp_options_association" "vpc" {
  count           = local.vpc_resource_count
  vpc_id          = aws_vpc.vpc[0].id
  dhcp_options_id = aws_vpc_dhcp_options.vpc[0].id
}

module "vpc_ipv4_cidr" {
  source          = "hashicorp/subnets/cidr"
  count           = local.vpc_resource_count
  base_cidr_block = aws_vpc.vpc[0].cidr_block # /16
  networks = [
    {
      name     = "app"
      new_bits = 3 # /19 - allows up to 8 /24 subnets (8192 IPs total, 256 per subnet)
    },
    {
      name     = "netdev"
      new_bits = 3 # /19 - allows up to 8 /24 subnets
    },
    {
      name     = "public"
      new_bits = 3 # /19 - allows up to 8 /24 subnets
    },
  ]
}

module "vpc_ipv6_cidr" {
  source          = "hashicorp/subnets/cidr"
  count           = local.vpc_resource_count
  base_cidr_block = aws_vpc.vpc[0].ipv6_cidr_block # /56
  networks = [
    {
      name     = "app"
      new_bits = 5 # /61 - allows up to 8 /64 subnets
    },
    {
      name     = "netdev"
      new_bits = 5 # /61 - allows up to 8 /64 subnets
    },
    {
      name     = "public"
      new_bits = 5 # /61 - allows up to 8 /64 subnets
    },
  ]
}

# VPC Flow log

locals {
  vpc_flow_log_enabled        = local.vpc_enabled && var.vpc_flow_log_enabled
  vpc_flow_log_resource_count = local.vpc_flow_log_enabled ? 1 : 0
  vpc_flow_log_name           = "${var.name_prefix}-vpc-flow-log-${local.region}"
}

resource "aws_flow_log" "vpc" {
  count           = local.vpc_flow_log_resource_count
  log_destination = aws_cloudwatch_log_group.vpc_flow_log[0].arn
  iam_role_arn    = aws_iam_role.vpc_flow_log[0].arn
  vpc_id          = aws_vpc.vpc[0].id
  traffic_type    = "ALL"
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  count             = local.vpc_flow_log_resource_count
  name              = local.vpc_flow_log_name
  retention_in_days = var.vpc_flow_log_retention_days
  kms_key_id        = module.kms_key.arn
  depends_on        = [module.kms_key.policy_dependency]
}

resource "aws_iam_role" "vpc_flow_log" {
  count              = local.vpc_flow_log_resource_count
  name               = local.vpc_flow_log_name
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_log_assume[0].json
}

resource "aws_iam_role_policy" "vpc_flow_log" {
  count  = local.vpc_flow_log_resource_count
  name   = aws_iam_role.vpc_flow_log[0].name
  role   = aws_iam_role.vpc_flow_log[0].id
  policy = data.aws_iam_policy_document.vpc_flow_log[0].json
}

data "aws_iam_policy_document" "vpc_flow_log" {
  count = local.vpc_flow_log_resource_count
  statement {
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }
  statement {
    actions   = ["logs:DescribeLogStreams"]
    resources = [aws_cloudwatch_log_group.vpc_flow_log[0].arn]
  }
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.vpc_flow_log[0].arn}:log-stream:*"]
  }
}

data "aws_iam_policy_document" "vpc_flow_log_assume" {
  count = local.vpc_flow_log_resource_count
  statement {
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "aws:SourceAccount"
    }
    condition {
      test     = "ArnLike"
      values   = ["arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*"]
      variable = "aws:SourceArn"
    }
  }
}

data "aws_iam_policy_document" "vpc_flow_log_kms_policy" {
  count = local.vpc_flow_log_resource_count
  statement {
    sid = "Allow VPC Flow log"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [module.kms_key.arn]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.vpc_flow_log_name}"]
    }
  }
}
