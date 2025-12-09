
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 1) Declare regions (alias -> region)
locals {
  regions = {
    ue1     = "us-east-1"
    uw2     = "us-west-2"
    ap_hyd  = "ap-south-1" # Mumbai, commonly used from Hyderabad
  }
}

# 2) Explicit provider blocks per region (cannot be dynamic)
provider "aws" {
  alias   = "ue1"
  region  = local.regions.ue1
  profile = "default"
}

provider "aws" {
  alias   = "uw2"
  region  = local.regions.uw2
  profile = "default"
}

provider "aws" {
  alias   = "ap_hyd"
  region  = local.regions.ap_hyd
  profile = "default"
}

# Optional: default provider (used if a resource/module doesn't override)
provider "aws" {
  region  = local.regions.ue1
  profile = "default"
}

# 3) Map alias -> actual provider handle (for easy lookup in for_each)
locals {
  region_providers = {
    ue1    = aws.ue1
    uw2    = aws.uw2
    ap_hyd = aws.ap_hyd
  }
}

# 4) Region-specific values (AMI, AZ counts, etc.)
locals {
  ami_by_region = {
    ue1    = "ami-xxxxxxxx" # us-east-1
    uw2    = "ami-yyyyyyyy" # us-west-2
    ap_hyd = "ami-zzzzzzzz" # ap-south-1
  }
}

# ---------------------------
# A) DRY PATTERN WITH RESOURCES
# ---------------------------
# Create one S3 bucket per region dynamically, each with its own provider
resource "aws_s3_bucket" "logs" {
  for_each = local.regions

  provider = local.region_providers[each.key]

  bucket   = "aparna-logs-${each.key}-${each.value}" # e.g. aparna-logs-ue1-us-east-1
  tags = {
    Owner       = "Lakshmi Aparna"
    RegionAlias = each.key
    Region      = each.value
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

# Example EC2 per region (shows region-specific AMI selection)
resource "aws_instance" "example" {
  for_each      = local.regions

  provider      = local.region_providers[each.key]
  ami           = local.ami_by_region[each.key]
  instance_type = "t3.micro"

  tags = {
    Name         = "example-${each.key}"
    Region       = each.value
  }
}

# ---------------------------
# B) DRY PATTERN WITH MODULES
# ---------------------------
# Prefer modules for larger stacks. One module call per region via for_each.
module "network" {
  source   = "./modules/network"
  for_each = local.regions

  # Pass inputs
  region   = each.value
  vpc_cidr = "10.${100 + index(keys(local.regions), each.key)}.0.0/16" # deterministic CIDR per alias

  # Key trick: override module's aws provider with per-region alias
  providers = {
    aws = local.region_providers[each.key]
  }
}

# You can consume outputs per region like:
output "vpc_ids" {
  value = {
    for k, m in module.network : k => m.vpc_id
  }
}

