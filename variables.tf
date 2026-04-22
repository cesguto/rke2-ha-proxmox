variable "pm_api_url" {
  description = "Proxmox API URL, e.g. https://192.168.0.5:8006/api2/json"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID, e.g. terraform-prov@pve!terraformToken"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Allow insecure TLS to the API"
  type        = bool
  default     = true
}

variable "pm_target_node" {
  description = "Proxmox node name to place the VMs on (e.g., proxmox-srv-001)"
  type        = string
}

variable "template_name" {
  description = "Existing Proxmox VM template name to clone (cloud-init enabled)"
  type        = string
}

variable "storage" {
  description = "Proxmox storage for the primary disk"
  type        = string
}

variable "bridge" {
  description = "Linux bridge in Proxmox"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "Optional VLAN tag (omit or set null for none)"
  type        = number
  default     = null
}

variable "ssh_public_key_file" {
  description = "Path to your SSH public key"
  type        = string
}

variable "gateway" {
  description = "Default gateway for the subnet"
  type        = string
  default     = "192.168.15.254"
}

variable "cidr_prefix" {
  description = "CIDR prefix (e.g., 24)"
  type        = number
  default     = 24
}

variable "vmid_base" {
  description = "Base VMID to start from; each VM adds an offset"
  type        = number
  default     = 200
}

variable "cpu_type" {
  description = "QEMU CPU type"
  type        = string
  default     = "host"
}

variable "storage_etcd" { 
    type = string
    default = "local-lvm" 
}
variable "storage_container" { 
    type = string
    default = "local-lvm"
}
variable "storage_kubelet" { 
    type = string
    default = "local-lvm" 
}
variable "storage_logs" { 
    type = string 
    default = "local-lvm" 
}

variable "storage_longhorn" {
  description = "Proxmox storage for the Longhorn data disk on worker nodes"
  type        = string
  default     = "local-lvm"
}

variable "size_etcd_gb" { 
    type = number
    default = 20 
}
variable "size_container_gb" { 
    type = number
    default = 120 
}
variable "size_kubelet_master_gb" { 
    type = number
    default = 40 
}
variable "size_kubelet_worker_gb" { 
    type = number
    default = 80 
}
variable "size_logs_gb" { 
    type = number
    default = 40 
}

variable "size_longhorn_gb" {
  description = "Longhorn data disk size (GB) on worker nodes"
  type        = number
  default     = 100
}

# Snippets de cloud-init (no storage snippets do Proxmox)
variable "ci_user_master" { 
    type = string
    default = "local-lvm:snippets/rke2-master-userdata.yaml" 
}
variable "ci_user_worker" { 
    type = string
    default = "local-lvm:snippets/rke2-worker-userdata.yaml" 
}

variable "proxmox_ssh_host" { 
    type = string
}

variable "proxmox_ssh_user" { 
    type = string
    default = "root" 
}

variable "proxmox_ssh_key_path" { 
    type = string
    default = "C:/Projetos/chaves/.ssh/id_ed25519" 
}

# Path inside the node where the cephfs snippets live (adjust if needed)
variable "snippets_dir" { 
    type = string
    default = "/var/lib/vz/snippets"
}

variable "snippets_storage" {
  description = "Proxmox storage ID that exposes content type 'snippets' (ex: local, cephfs)"
  type        = string
  default     = "local"
}

variable "cloudinit_storage" {
  type        = string
  description = "Storage to hold the cloud-init ISO"
  default     = "local-lvm"  # or "local-lvm"
}

variable "ci_username" {
  type        = string
  default     = "ubuntu"   # must match your image’s default user
  description = "Default user for cloud-init"
}

variable "ci_password_hash" {
  type        = string
  sensitive   = true
  description = "Hash no formato crypt (não é a senha em texto). Ex.: SHA-512 ($6$...) ou yescrypt ($y$...). Gerar: openssl passwd -6  ou mkpasswd --method=SHA-512"
  validation {
    condition     = length(var.ci_password_hash) >= 20 && startswith(var.ci_password_hash, "$")
    error_message = "ci_password_hash tem de ser um hash crypt (começa com '$', ex. $6$... ou $y$...). Texto plano não funciona no campo passwd do cloud-init."
  }
}