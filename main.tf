module "network" {
  source = "./modules/network"

  admin_ip = var.admin_ip
}

module "compute" {
  source = "./modules/compute"

  subnet_id         = module.network.subnet_id
  security_group_id = module.network.security_group_id
  ssh_public_key    = file(var.ssh_public_key_path)
}
