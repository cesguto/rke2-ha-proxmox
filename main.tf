provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
}

locals {
  # Only real VMs here (VIPs are excluded)
  vms = {
    rke2-master1 = { ip = "192.168.0.211", role = "control-plane", cores = 3,  memory = 4096, disk_gb = 60 }
    rke2-master2 = { ip = "192.168.0.212", role = "control-plane", cores = 3,  memory = 4096, disk_gb = 60 }
    rke2-master3 = { ip = "192.168.0.213", role = "control-plane", cores = 3,  memory = 4096, disk_gb = 60 }
    rke2-agent1  = { ip = "192.168.0.214", role = "worker",        cores = 2,  memory = 8192, disk_gb = 80 }
    rke2-agent2  = { ip = "192.168.0.215", role = "worker",        cores = 2,  memory = 8192, disk_gb = 80 }
    rke2-agent3  = { ip = "192.168.0.216", role = "worker",        cores = 2,  memory = 8192, disk_gb = 80 }
    rke2-ha1     = { ip = "192.168.0.217", role = "ha-proxy",      cores = 1,  memory = 2048,  disk_gb = 20 }
    rke2-ha2     = { ip = "192.168.0.218", role = "ha-proxy",      cores = 1,  memory = 2048,  disk_gb = 20 }
  }

  # Keep order stable to derive VMIDs deterministically
  vm_order = [
    "rke2-master1",
    "rke2-master2",
    "rke2-master3",
    "rke2-agent1",
    "rke2-agent2",
    "rke2-agent3",
    "rke2-ha1",
    "rke2-ha2"
  ]

  vmid_map = tomap({
    for idx, name in local.vm_order :
    name => var.vmid_base + idx
  })

  # VIPs (informational only, no VMs created)
  vips = {
    rke2_vip_lb = "192.168.0.210" # MetalLB VIP (K8s level)
    rke2_ha_vip = "192.168.0.219" # Keepalived/HAProxy VIP
  }

  snippet_role_map = {
    rke2-master1 = "rke2-master-userdata.tpl"
    rke2-master2 = "rke2-master-userdata.tpl"
    rke2-master3 = "rke2-master-userdata.tpl"
    rke2-agent1  = "rke2-worker-userdata.tpl"
    rke2-agent2  = "rke2-worker-userdata.tpl"
    rke2-agent3  = "rke2-worker-userdata.tpl"
    rke2-ha1     = "ha-userdata.tpl"
    rke2-ha2     = "ha-userdata.tpl"
  }
  # keys that actually need upload
  snippet_vms = keys(local.snippet_role_map)
  network_vms = keys(local.vms)
  # Masters/agents: user + network
  # HA nodes: apenas network
  cicustom_map = merge(
    { for k in local.network_vms : k => "network=${var.snippets_storage}:snippets/${k}-network.yml" },
    { for k in local.snippet_vms : k => "user=${var.snippets_storage}:snippets/${k}.yml,network=${var.snippets_storage}:snippets/${k}-network.yml" }
  )
  # Lista de resolvers para o Netplan (cloud-init); ordem = prioridade de uso típica do glibc/systemd-resolved
  dns_servers = ["192.168.0.1", "8.8.8.8"]

  dns_addresses_yaml = join("\n", [for a in local.dns_servers : "        - ${a}"])

  target_node_map = {
    "rke2-master1" = "pve"
    "rke2-agent1"  = "pve"
    "rke2-ha1"     = "pve"
    "rke2-master2" = "pve"
    "rke2-agent2"  = "pve"
    "rke2-ha2"     = "pve"
    "rke2-master3" = "pve"
    "rke2-agent3"  = "pve"
  }
}

resource "local_file" "network_data" {
  for_each = toset(local.network_vms)
  filename = "${path.module}/.rendered/${each.key}-network.yml"
  content = templatefile("${path.module}/templates/net-common.yaml", {
    ip                 = local.vms[each.key].ip
    cidr_prefix        = var.cidr_prefix
    gateway            = var.gateway
    dns_addresses_yaml = local.dns_addresses_yaml
  })
}

resource "null_resource" "upload_network_snippet" {
  for_each = toset(local.network_vms)

  connection {
    type        = "ssh"
    user        = var.proxmox_ssh_user
    private_key = file(var.proxmox_ssh_key_path)
    host        = var.proxmox_ssh_host
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p ${var.snippets_dir}"]
  }

  provisioner "file" {
    source      = local_file.network_data[each.key].filename  # implicit dep on local_file
    destination = "${var.snippets_dir}/${each.key}-network.yml"
  }

  # 🔧 No reference to the rendered file here
  triggers = {
    tpl_hash = filesha256("${path.module}/templates/net-common.yaml")
    vm_vars  = sha1(jsonencode({
      ip          = local.vms[each.key].ip
      cidr_prefix = var.cidr_prefix
      gateway     = var.gateway
      dns_servers         = local.dns_servers
    }))
  }
}

# Render one file per VM (you can swap templatefile(...) -> file(...) if you don't use vars)
resource "local_file" "user_data" {
  for_each = toset(local.snippet_vms)
  filename = "${path.module}/.rendered/${each.key}.yml"
  content  = templatefile("${path.module}/templates/${local.snippet_role_map[each.key]}", {
    username      = var.ci_username
    password_hash = var.ci_password_hash
    ssh_key       = trimspace(file(var.ssh_public_key_file))
    name          = each.key
  })
}

# Upload each rendered file to the node's snippets dir
resource "null_resource" "upload_snippet" {
  for_each = toset(local.snippet_vms)

  connection {
    type        = "ssh"
    user        = var.proxmox_ssh_user
    private_key = file(var.proxmox_ssh_key_path)
    host        = var.proxmox_ssh_host
  }

  # make sure the dir exists (nice to have)
  provisioner "remote-exec" {
    inline = ["mkdir -p ${var.snippets_dir}"]
  }

  provisioner "file" {
    source      = local_file.user_data[each.key].filename
    destination = "${var.snippets_dir}/${each.key}.yml"
  }

  # Re‑upload when local file changes
  triggers = {
    tpl_hash = filesha256("${path.module}/templates/${local.snippet_role_map[each.key]}")
  }
}

# One VM per entry in local.vms
resource "proxmox_vm_qemu" "vm" {
  for_each    = local.vms

  # depend on the per‑VM snippet upload if one exists
  depends_on = [ 
    null_resource.upload_snippet,
    null_resource.upload_network_snippet
  ]

  name        = each.key
  vmid        = local.vmid_map[each.key]

  target_node = local.target_node_map[each.key]

  clone       = var.template_name
  full_clone  = true
  onboot      = true

  agent       = 1
  agent_timeout = 30
  skip_ipv6   = true

  # CPU (v3 style)
  cpu {
    type = var.cpu_type   # e.g. "host"
    sockets  = 1
    cores    = each.value.cores
  }

  memory      = each.value.memory

  # SCSI controller + bootdisk label
  scsihw      = "virtio-scsi-pci"
  bootdisk    = "scsi0"
  # Attach the Cloud-Init CDROM (required for ipconfig0, cicustom, etc.)
  disk {
    slot    = "ide2"          # cloud-init must be on ide2 in Proxmox
    type    = "cloudinit"
    storage = var.cloudinit_storage
  }
  # Ensure the VM boots from the OS disk (not PXE)
  boot = "order=scsi0"

  # Disk (v3 expects bus in the slot string, and type=‘disk’)
  disk {
    slot    = "scsi0"                 # bus+index label (scsi0/scsi1/... or virtio0/..., sata0/..., etc.)
    type    = "disk"                  # device kind, not the bus
    storage = var.storage
    size    = "${each.value.disk_gb}G"
    format  = "raw"                   # Explicitly set the disk format
  }

  # ---- Discos extras para MASTERS (A,B,C,D) ----
dynamic "disk" {
  for_each = contains(["rke2-master1","rke2-master2","rke2-master3"], each.key) ? [
    {
      slot    = "scsi1",
      type    = "disk",
      storage = var.storage_etcd,
      size    = "${var.size_etcd_gb}G"
    },
    {
      slot    = "scsi2",
      type    = "disk",
      storage = var.storage_container,
      size    = "${var.size_container_gb}G"
    },
    {
      slot    = "scsi3",
      type    = "disk",
      storage = var.storage_kubelet,
      size    = "${var.size_kubelet_master_gb}G"
    },
    {
      slot    = "scsi4",
      type    = "disk",
      storage = var.storage_logs,
      size    = "${var.size_logs_gb}G"
    }
  ] : []
  content {
    slot    = disk.value.slot
    type    = disk.value.type
    storage = disk.value.storage
    size    = disk.value.size
    format  = "raw"
  }
}

# ---- Discos extras para WORKERS (B',C',D') ----
dynamic "disk" {
  for_each = contains(["rke2-agent1","rke2-agent2","rke2-agent3"], each.key) ? [
    {
      slot    = "scsi1",
      type    = "disk",
      storage = var.storage_container,
      size    = "${var.size_container_gb}G"
    },
    {
      slot    = "scsi2",
      type    = "disk",
      storage = var.storage_kubelet,
      size    = "${var.size_kubelet_worker_gb}G"
    },
    {
      slot    = "scsi3",
      type    = "disk",
      storage = var.storage_logs,
      size    = "${var.size_logs_gb}G"
    },
    {
      slot    = "scsi4",
      type    = "disk",
      storage = var.storage_longhorn,
      size    = "${var.size_longhorn_gb}G"
    }
  ] : []
  content {
    slot    = disk.value.slot
    type    = disk.value.type
    storage = disk.value.storage
    size    = disk.value.size
    format  = "raw"
  }
}

  # Network (id required; tag is VLAN id, 0 = untagged)
  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
    tag    = var.vlan_id == null ? 0 : var.vlan_id
  }

  # Cloud-init
  ipconfig0 = "ip=${each.value.ip}/${var.cidr_prefix},gw=${var.gateway}"
  tags = "rke2;${each.value.role}"
  cicustom = local.cicustom_map[each.key]

  lifecycle {
    ignore_changes = [bootdisk]
  }
}