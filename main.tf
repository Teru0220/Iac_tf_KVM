# Worker Node 1 の設定
resource "libvirt_domain" "worker_node" {
  count  = var.worker_count
  name   = format("worker-node-%02d", count.index + 1)
  memory = 8192
  memory_unit = "MiB"
  vcpu   = 2
  type   = "kvm"

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35" # Q35 を使用
    boot_devices = [{ dev = "hd" }]
  }

  cpu = {
    mode = "host-passthrough"
  }

  features = {
    acpi = true
    apic = {}
  }

  devices = {
    disks = [
      # メインの VirtIO ディスク
      {
        source = {
          volume = {
            pool   = libvirt_volume.worker_disk[count.index].pool
            volume = libvirt_volume.worker_disk[count.index].name
          }
        }
        driver = {
          type    = "qcow2"
          discard = "unmap"
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      }
    ]

    interfaces = [
      {
        model  = { type = "virtio" }
        source = { network = { network = "default" } }
      }
    ]

    consoles = [
      { target = { type = "serial", port = "0" } }
    ]

    graphics = [
      { spice = { auto_port = true, listeners = [{ address = {} }] } }
    ]
  }
}

# ディスクボリュームの作成（クラウドイメージ用ベース設定）
resource "libvirt_volume" "worker_disk" {
  count    = var.worker_count
  name     = format("worker-%02d.qcow2", count.index + 1)
  pool     = "default"
  capacity = 42949672960 # 40GB

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path   = var.image_path
    format = {
      type = "qcow2"
    }
  }
}