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

module "load_balancer_controller" {
  source = "./modules/load_balancer_controller"

  aws_region        = var.aws_region
  cluster_name      = module.eks.cluster_name
  vpc_id            = module.network.vpc_id
  oidc_issuer_url   = module.eks.oidc_issuer_url
  oidc_provider_arn = module.eks.oidc_provider_arn
}

module "argocd" {
  source = "./modules/argocd"

  repository_url = var.gitops_repository_url

  # No destroy o Argo CD sai antes do controller, que ainda remove os ALBs
  # dos Ingress apagados pelo Argo CD.
  depends_on = [module.load_balancer_controller]
}
