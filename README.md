# KVM ノードプロビジョニング

Terraform と `dmacvicar/libvirt` provider を使用して、ローカルの KVM/libvirt 環境へ複数の仮想ノードと qcow2 ボリュームを作成する構成です。

## 構成

```text
composition/
  main.tf              # nodes を for_each で展開するルート構成
  variables.tf         # nodes の型定義
  terraform.tfvars     # 作成するノードの具体的な設定
  provider.tf          # libvirt provider
  tests/               # terraform test 用のテスト

infrastructure_module/
  main.tf              # 1ノード分の volume/domain module を接続
  variables.tf
  outputs.tf

resource_module/
  libvirt_volume/      # 1ボリュームを作成
  libvirt_domain/      # 1ドメインを作成
```

処理の流れは次のとおりです。

```text
composition
  -> infrastructure_module (node 単位)
    -> libvirt_volume
    -> libvirt_domain
```

`for_each` は `composition` だけで使用します。下位 module は常に1つの `node` を処理し、volume の output を domain module に渡します。

## 前提条件

- Linux
- Terraform 1.6 以上
- KVM/libvirt
- `qemu:///system` に接続できる libvirt 環境
- `dmacvicar/libvirt` provider 0.9.9
- OS をインストール済みの既存 qcow2 イメージ

この構成は、OS 未インストールの空ディスクからノードを作成するものではありません。あらかじめ OS、ブートローダー、必要な初期設定を済ませた qcow2 イメージを用意し、それを各ノードの元イメージとしてクローンする必要があります。

`image_path` には、その既存 qcow2 イメージの絶対パスを指定してください。`libvirt_volume` は `backing_store` を使用してこのイメージを backing image とする qcow2 volume を作成し、各ノードのドメインへ接続します。

```text
OS インストール済み qcow2
  |
  +-- node-01.qcow2 -> node-01
  +-- node-02.qcow2 -> node-02
```

イメージが存在しない場合、パスや形式が実際のファイルと異なる場合、または OS がインストールされていない場合は、ノードの作成や起動に失敗します。Terraform を実行するユーザーから読み取り可能な場所にイメージを配置してください。

provider は [composition/provider.tf](composition/provider.tf) で次の URI を使用します。

```hcl
provider "libvirt" {
  uri = "qemu:///system"
}
```

Terraform 実行ユーザーが libvirt を操作できることを確認してください。

## ノード設定

具体的な設定は [composition/terraform.tfvars](composition/terraform.tfvars) の `nodes` 配列に記述します。ノードごとに全パラメータを個別指定できます。

```hcl
nodes = [
  {
    domain_name        = "node-01"
    volume_name        = "node-01.qcow2"
    image_path         = "/path/to/image.qcow2"
    volume_pool        = "default"
    volume_capacity    = 42949672960
    volume_format      = "qcow2"
    volume_target      = { format = { type = "qcow2" } }
    domain_memory      = 8192
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
      interfaces = [{
        model  = { type = "virtio" }
        source = { network = { network = "default" } }
      }]
      consoles = [{ target = { type = "serial", port = "0" } }]
      graphics = [{ spice = { auto_port = true, listeners = [{ address = {} }] } }]
    }
  }
]
```

### 主なパラメータ

| パラメータ | 説明 |
| --- | --- |
| `domain_name` | libvirt ドメイン名。`nodes` の `for_each` キーにも使用 |
| `volume_name` | 作成する libvirt volume 名 |
| `image_path` | backing image の絶対パス |
| `volume_pool` | libvirt storage pool |
| `volume_capacity` | volume 容量（byte） |
| `volume_format` | volume と backing image の形式 |
| `volume_target` | volume の target 設定 |
| `domain_memory` | メモリ容量 |
| `domain_memory_unit` | メモリ単位 |
| `domain_vcpu` | vCPU 数 |
| `domain_type` | libvirt の仮想化タイプ |
| `disk_driver` | ドメインディスクの driver 設定 |
| `disk_target` | ドメインディスクの target 設定 |
| `os` | OS、アーキテクチャ、machine、boot 設定 |
| `cpu` | CPU モード |
| `features` | ACPI/APIC などの機能 |
| `devices` | ネットワーク、コンソール、グラフィックなどのデバイス |

`domain_name` は重複できません。重複すると `composition` の `for_each` キーが衝突します。

## 実行方法

作業ディレクトリを `composition` にして実行します。

```bash
cd composition
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

適用後は作成された名前を確認できます。

```bash
terraform output domain_names
terraform output volume_names
```

削除する場合は、同じ `composition` ディレクトリで実行します。

```bash
terraform destroy
```

## テスト

native Terraform test を使用しています。テストは `plan` モードで実行されるため、libvirt リソースを実際には作成しません。

```bash
terraform -chdir=composition test
```

テストファイルは [composition/tests/nodes.tftest.hcl](composition/tests/nodes.tftest.hcl) です。複数の node から domain と volume が生成され、それぞれの名前が設定値どおりになることを検証します。

## コンソール接続

ゲスト OS 側でシリアルログインを有効にした後、次のコマンドで接続できます。

```bash
virsh console node-01 --force
```

GRUB と serial getty の設定例:

```bash
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8 /' /etc/default/grub
sudo update-grub
sudo systemctl enable --now serial-getty@ttyS0.service
```

## 注意事項

- `image_path` は実行環境から参照できるパスを指定してください。
- `domain_name` や `volume_name` を変更すると、Terraform は既存リソースを別リソースとして扱う場合があります。
- 既存 state がある状態で resource/module 名を変更した場合は、`terraform plan` を確認してから apply してください。
- KVM/libvirt 上の手動変更は Terraform state と不一致になるため、可能な限り Terraform 経由で管理してください。

## 参考ファイル

- [terraform.tfvars.example](terraform.tfvars.example)
- [composition/main.tf](composition/main.tf)
- [infrastructure_module/main.tf](infrastructure_module/main.tf)
- [resource_module/libvirt_volume/main.tf](resource_module/libvirt_volume/main.tf)
- [resource_module/libvirt_domain/main.tf](resource_module/libvirt_domain/main.tf)
