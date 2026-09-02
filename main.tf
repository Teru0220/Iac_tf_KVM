# Worker Node 1 の設定
resource "libvirt_domain" "worker_node" {
  count  = var.worker_count
  name   = format("worker-node-%02d", count.index + 1)
  memory = 8192
  memory_unit = "MiB"
  vcpu   = 2
  type        = "kvm"

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc"
    boot_devices = [
      { dev = "hd" }
    ]
  }

  devices = {
    disks = [
      {
        source = {
          file = {
            file = "/var/lib/libvirt/images/worker-${format("%02d", count.index + 1)}.qcow2"
          }
        }
        driver = {
          type = "qcow2"
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      }
    ]
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
      }
    ]
    consoles = [
      {
        target = {
          type = "serial"
          port = "0"
        }
      }
    ]
    graphics = [
      {
        spice = {
          autoport = true
        }
        listen = {
          type = "address"
        }
      }
    ]
  }
}

# ディスクボリュームの作成（クラウドイメージ用ベース設定）
resource "libvirt_volume" "worker_disk" {
  count    = var.worker_count
  name     = format("worker-%02d.qcow2", count.index + 1)
  pool     = "default"
  capacity = 42949672960 # 40GB (バイト指定)

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