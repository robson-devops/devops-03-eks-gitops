locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tag = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # /20: com a VPC CNI cada pod consome um IP da subnet.
  public_subnet = {
    a = {
      availability_zone = "${var.aws_region}a"
      cidr_block        = cidrsubnet(var.vpc_cidr, 4, 0)
    }
    b = {
      availability_zone = "${var.aws_region}b"
      cidr_block        = cidrsubnet(var.vpc_cidr, 4, 1)
    }
  }

  private_subnet = {
    a = {
      availability_zone = "${var.aws_region}a"
      cidr_block        = cidrsubnet(var.vpc_cidr, 4, 8)
    }
    b = {
      availability_zone = "${var.aws_region}b"
      cidr_block        = cidrsubnet(var.vpc_cidr, 4, 9)
    }
  }
}
