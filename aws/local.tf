
variable "region" {
  type        = string
  description = "Region the module should operate in"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

# The module itself simply uses 'aws_*' resources—no aliases needed here.
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name       = "vpc-${var.region}"
    ManagedBy  = "Terraform"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "public-${count.index}-${var.region}"
  }
}

output "vpc_id" {
  value = aws_vpc.this.id
}

