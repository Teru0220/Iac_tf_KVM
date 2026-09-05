# IAAC_tf_KVM 構築対応記録 (Development Log)

## 概要
本プロジェクトは、KVM (Libvirt) 上に Kubernetes プラットフォームを構築するための Infrastructure as Code (IaC) 環境の整備記録である。単一の記述ファイル（モノリシック構成）から出発し、「Terraform Best Practices」に準拠した Composition パターン（3 階層構造）への移行を行った。

---

## 対応履歴・詳細

### 1. 初期検証と動作要件の確定
* **`q35` マシンタイプの動作安定化**
  * `q35` マシンタイプで VM を正常起動させるため、`acpi = true` および `apic = {}` のフラグ設定が必須であることを特定・適用。
* **リソーススペックの策定**
  * **Control Plane**: 4GB RAM, 40GB Disk, 2 vCPU
  * **Worker Nodes**: 8GB RAM, 40GB Disk, 2 vCPU (×2 台)
* **実環境の動作検証**
  * 最小構成の `libvirt_domain` / `libvirt_volume` を使用し、SSH 接続およびネットワーク疎通（`192.168.122.131/24`）を確認。

---

### 2. Composition パターンに基づく 3 階層構造の策定
公式ドキュメント (`terraform-best-practices.com`) の Composition 設計原則に従い、ディレクトリ構造を以下の 3 段階に再設計。

1. **`composition/`（最上位・ルート）**
   * インフラ全体のオーケストレーション。`for_each` を用いて変数のマップから動的にノードをプロビジョニング。
2. **`infrastructure_module/`（中間層・論理まとめ）**
   * 個々のリソースを組み合わせ、「KVM ノード」という論理単位としてまとめるモジュール。
3. **`resource_module/`（最下層・アトミックリソース）**
   * `libvirt_domain` や `libvirt_volume` など、単一リソースのみを管理する最小モジュール。
