locals {
  # NAT único (trade-off de custo, ver README).
  nat_subnet_key = sort(keys(var.public_subnet))[0]
}
