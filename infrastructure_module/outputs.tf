output "volume_name" {
  description = "Name of the created libvirt volume"
  value       = module.volume.volume_name
}

output "domain_name" {
  description = "Name of the created libvirt domain"
  value       = module.domain.domain_name
}
