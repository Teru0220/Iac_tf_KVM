variable "image_path" {
  description = "Path to the base image for worker nodes"
  type        = string
  default     = "./images/tmp_disk.qcow2" # 代替となる汎用的な相対パス
}

variable "worker_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 2
}