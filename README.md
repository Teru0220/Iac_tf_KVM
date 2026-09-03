```markdown
# Libvirt / QEMU 環境における KVM 仮想ノードプロビジョニングのトラブルシューティングと構成ガイド

本ドキュメントは、Terraform (`dmacvicar/libvirt` プロバイダー v0.9.x) を使用して KVM 上に Kubernetes ワーカーノードを自動デプロイする際発生した課題、原因究明、および最終的な解決構成についてまとめたものです。

---

## 1. 発生した課題と経緯

### 1-1. ディスクフォーマット認識エラー (`raw` へのフォールバック)
* **症状**: `qcow2` 形式のイメージを指定しているにもかかわらず、`raw` フォーマットとして認識されブートに失敗。
* **原因**: `dmacvicar/libvirt` (v0.9.x) プロバイダー仕様上、`disk` ブロック内で明示的なフォーマットおよびドライバーの宣言を行わない場合、デフォルトの `raw` にフォールバックするため。
* **解決策**:
  ```hcl
  driver = { type = "qcow2" }
  target = { dev = "vda", bus = "virtio" }

```

上記を明示的に指定することで正常認識を確保。

### 1-2. `type_machine = "q35"` 使用時のカーネルフリーズ (`pciehp` ループ)

* **症状**: OS 起動中に `pciehp: Slot(0): Card not present` などのメッセージで停止し、ログイン画面まで到達しない。
* **原因**:
* GUI ツール (`virt-manager`) は `q35` マシンタイプ選択時に PCIe コントローラーやビデオカード、グラフィック設定を自動補完する。
* IaC (Terraform) では最低限のデバイスしか追加されないため、QEMU が自動生成する PCIe Root Port と OS (Ubuntu) 側の PCIe ホットプラグドライバ間で割り込み衝突・ループが発生。


* **解決策**: 一時的に `type_machine = "pc"` (i440fx) へ変更してブートを確認後、本質的解決として `graphics` および `videos` デバイスを明示構成に組み込む方針へ移行。

### 1-3. Terraform State クラッシュ (`ObjectStatus(0)`)

* **症状**: 破壊された VM 状態のまま `terraform apply` / `destroy` を実行した際、`Instance libvirt_domain... has status ObjectStatus(0)` で panic クラッシュが発生。
* **原因**: 不正な状態で残ったリソースを Terraform Core が state ファイルへ書き込めずパニックを起こした。
* **解決策**:
1. `terraform state rm "libvirt_domain.worker_node[0]"` で壊れたリソースをステートから手動切離し。
2. `virsh destroy` / `virsh undefine` で KVM 上の孤立ドメインを消去後、再実行。



### 1-4. CUI ノードにおける画面出力・コンソールアクセス不能

* **症状**: シリアルコンソール (`virsh console`) や `virt-viewer` で画面が暗転またはプロンプトが出力されない。
* **原因**: CUI OS であってもテキストを描画・出力するための仮想 GPU (`videos`) および通信プロトコル (`graphics`) が未定義だったため。

---

## 2. 解決後の構造設計 (IaC / HCL)

`dmacvicar/libvirt` (v0.9.x) において、`q35` チップセットを維持しつつ CUI ノードへ確実にアクセスするための推奨構成です。

```hcl
resource "libvirt_domain" "worker_node" {
  count       = var.worker_count
  name        = format("worker-node-%02d", count.index + 1)
  memory      = 8192
  memory_unit = "MiB"
  vcpu        = 2
  type        = "kvm"

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [
      { dev = "hd" }
    ]
  }

  devices = {
    # ディスク設定 (qcow2 明示指定)
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.worker_disk[count.index].pool
            volume = libvirt_volume.worker_disk[count.index].name
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

    # ネットワーク設定
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

    # シリアルコンソール (virsh console 用)
    consoles = [
      {
        target = {
          type = "serial"
          port = "0"
        }
      }
    ]

    # グラフィック転送設定 (VNC)
    graphics = [
      {
        type = "vnc"
        listen = {
          type    = "address"
          address = "0.0.0.0"
        }
      }
    ]

    # 仮想ビデオカード (CUIのテキスト画面描画用)
    videos = [
      {
        model = {
          type = "virtio"
        }
      }
    ]
  }

  depends_on = [libvirt_volume.worker_disk]
}

```

---

## 3. コンソール接続・運用ナレッジ

* **シリアルコンソールセッションの競合解除**:
前回の接続がバックグラウンドに残った場合は `--force` オプションで上書き接続する。
```bash
virsh console worker-node-01 --force

```


* **ゲスト OS 側の GRUB シリアル出力有効化**:
`virsh console` 経由でログイン画面を常時出力させたい場合は、ゲスト OS 側で以下を適用する。
```bash
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8 /' /etc/default/grub
sudo update-grub
sudo systemctl enable --now serial-getty@ttyS0.service

```



```

```
