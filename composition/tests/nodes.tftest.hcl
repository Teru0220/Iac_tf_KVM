run "nodes_are_created_from_the_nodes_variable" {
  command = plan

  variables {
    nodes = [
      {
        domain_name        = "test-node-01"
        volume_name        = "test-node-01.qcow2"
        image_path         = "/tmp/test-node-01.qcow2"
        volume_pool        = "default"
        volume_capacity    = 1073741824
        volume_format      = "qcow2"
        volume_target      = { format = { type = "qcow2" } }
        domain_memory      = 2048
        domain_memory_unit = "MiB"
        domain_vcpu        = 1
        domain_type        = "kvm"
        disk_driver        = { type = "qcow2", discard = "unmap" }
        disk_target        = { dev = "vda", bus = "virtio" }
        os = {
          type         = "hvm"
          type_arch    = "x86_64"
          type_machine = "q35"
          boot_devices = [{ dev = "hd" }]
        }
        cpu      = { mode = "host-passthrough" }
        features = { acpi = true, apic = {} }
        devices = {
          interfaces = [{ model = { type = "virtio" }, source = { network = { network = "default" } } }]
          consoles   = [{ target = { type = "serial", port = "0" } }]
          graphics   = [{ spice = { auto_port = true, listeners = [{ address = {} }] } }]
        }
      },
      {
        domain_name        = "test-node-02"
        volume_name        = "test-node-02.qcow2"
        image_path         = "/tmp/test-node-02.qcow2"
        volume_pool        = "default"
        volume_capacity    = 2147483648
        volume_format      = "qcow2"
        volume_target      = { format = { type = "qcow2" } }
        domain_memory      = 4096
        domain_memory_unit = "MiB"
        domain_vcpu        = 2
        domain_type        = "kvm"
        disk_driver        = { type = "qcow2", discard = "unmap" }
        disk_target        = { dev = "vda", bus = "virtio" }
        os = {
          type         = "hvm"
          type_arch    = "x86_64"
          type_machine = "q35"
          boot_devices = [{ dev = "hd" }]
        }
        cpu      = { mode = "host-passthrough" }
        features = { acpi = true, apic = {} }
        devices = {
          interfaces = [{ model = { type = "virtio" }, source = { network = { network = "default" } } }]
          consoles   = [{ target = { type = "serial", port = "0" } }]
          graphics   = [{ spice = { auto_port = true, listeners = [{ address = {} }] } }]
        }
      }
    ]
  }

  assert {
    condition     = output.domain_names == { "test-node-01" = "test-node-01", "test-node-02" = "test-node-02" }
    error_message = "Each node must produce a domain with its configured domain_name."
  }

  assert {
    condition     = output.volume_names == { "test-node-01" = "test-node-01.qcow2", "test-node-02" = "test-node-02.qcow2" }
    error_message = "Each node must produce a volume with its configured volume_name."
  }
}
