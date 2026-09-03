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

  metadata = {
    xml ="<libosinfo:libosinfo xmlns:libosinfo='http://libosinfo.org/xmlns/libvirt/domain/1.0'><libosinfo:os id='http://ubuntu.com/ubuntu/24.04'/></libosinfo:libosinfo>"
  }

  features = {
    acpi = true
    apic = {}
    vm_port = { 
      state = "off"
    }
  }

  # Control Plane と同一のタイマー設定（HPET 無効化）
  clock = {
    offset = "utc"
    timer = [
      { name = "rtc",  tick_policy = "catchup" },
      { name = "pit",  tick_policy = "delay" },
      { name = "hpet", present = "no" }
    ]
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

    videos = [
      { model = { type = "virtio" } }
    ]

    channels = [
      {
        source = { unix = {} }
        target = { virt_io = { name = "org.qemu.guest_agent.0" } }
      },
      {
        source = { spice_vmc = true }
        target = { virt_io = { name = "com.redhat.spice.0" } }
      }
    ]

    # エントロピー（乱数）不足による起動遅延を防ぐ VirtIO-RNG
    rngs = [
      {
        backend = {
          random = "/dev/urandom"
        }
        model = "virtio"
      }
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