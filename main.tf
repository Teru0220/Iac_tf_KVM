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
    type_machine = "q35"
    boot_devices = [
      { dev = "hd" },
      { dev = "network" }
    ]
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.worker_disk[count.index].pool
            volume = libvirt_volume.worker_disk[count.index].name
          }
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

    create = {
    content = {
      url = var.image_path
    }
  }
}