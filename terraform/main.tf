module "network" {
  source = "./modules/network"

  name_prefix    = local.name_prefix
  vpc_cidr       = var.vpc_cidr
  public_subnet  = local.public_subnet
  private_subnet = local.private_subnet
}

module "eks" {
  source = "./modules/eks"

  cluster_name                = local.name_prefix
  cluster_version             = var.cluster_version
  subnet_id                   = module.network.private_subnet_id
  endpoint_public_access_cidr = var.operator_cidr
}
