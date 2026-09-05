output "domain_name" {
  description = "Name of the created libvirt domain"
  value       = libvirt_domain.domain.name
}