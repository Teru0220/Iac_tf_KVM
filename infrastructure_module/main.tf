module "volume" {
  source = "../resource_module/libvirt_volume"

  node = var.node
}

module "domain" {
  source = "../resource_module/libvirt_domain"

  node        = var.node
  volume_name = module.volume.volume_name

}
