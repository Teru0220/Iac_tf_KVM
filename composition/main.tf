module "infrastructure" {
  source = "../infrastructure_module"
  for_each = {
    for node in var.nodes : node.domain_name => node
  }

  node = each.value
}
