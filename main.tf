module "network" {
  source = "./modules/network"

  admin_ip = var.admin_ip
}

module "compute" {
  source = "./modules/compute"

  subnet_id         = module.network.subnet_id
  security_group_id = module.network.security_group_id
  ssh_public_key    = file(var.ssh_public_key_path)
  use_elastic_ip    = var.use_elastic_ip
}

module "storage" {
  source = "./modules/storage"

  instance_id = module.compute.instance_id
}

module "backup" {
  source = "./modules/backup"
}

module "budget" {
  source = "./modules/budget"

  alert_email   = var.alert_email
  monthly_limit = var.monthly_budget_usd
}

module "dns" {
  source = "./modules/dns"

  zone_id     = var.cloudflare_zone_id
  record_name = var.dns_record_name
  elastic_ip  = module.compute.public_ip
}
