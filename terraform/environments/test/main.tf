# Generate SSH key for Ansible user
resource "tls_private_key" "ansible" {
  algorithm = "ED25519"
}

# All shared variables here
locals {
  # Shared Proxmox & cloud-init credentials
  pve_host                = var.pve_host
  pve_user                = var.pve_user
  pve_password            = var.pve_password
  server_admin_public_key = var.server_admin_public_key

  # Shared VM settings
  target_node = "pve"
}

module "bastion-ubuntu-test" {
  vmid        = 201
  source      = "../../modules/proxmox-vm-ubuntu-24-cloudinit"
  name        = "bastion-ubuntu-test"
  target_node = local.target_node
  cores       = 2
  memory      = 2048
  sockets     = 1
  disk_size   = "16G"
  ipconfig0   = "ip=192.168.1.170/24,gw=192.168.1.1"

  is_ansible_runner   = true
  ansible_public_key  = tls_private_key.ansible.public_key_openssh
  ansible_private_key = tls_private_key.ansible.private_key_openssh

  server_admin_public_key = local.server_admin_public_key
  pve_host                = local.pve_host
  pve_user                = local.pve_user
  pve_password            = local.pve_password
}

module "media-ubuntu-test" {
  vmid        = 202
  source      = "../../modules/proxmox-vm-ubuntu-24-cloudinit"
  name        = "media-ubuntu-test"
  target_node = local.target_node
  cores       = 2
  memory      = 2048
  sockets     = 1
  disk_size   = "16G"
  ipconfig0   = "ip=192.168.1.171/24,gw=192.168.1.1"

  ansible_public_key = tls_private_key.ansible.public_key_openssh

  server_admin_public_key = local.server_admin_public_key
  pve_host                = local.pve_host
  pve_user                = local.pve_user
  pve_password            = local.pve_password

  extra_disk_storage = "additional-storage" # Name of the Proxmox storage
  extra_disk_size    = "10G"
}

module "k3s-ubuntu-test" {
  vmid        = 203
  source      = "../../modules/proxmox-vm-ubuntu-24-cloudinit"
  name        = "k3s-ubuntu-test"
  target_node = local.target_node
  cores       = 2
  memory      = 2048
  sockets     = 1
  disk_size   = "16G"
  ipconfig0   = "ip=192.168.1.172/24,gw=192.168.1.1"

  ansible_public_key = tls_private_key.ansible.public_key_openssh

  server_admin_public_key = local.server_admin_public_key
  pve_host                = local.pve_host
  pve_user                = local.pve_user
  pve_password            = local.pve_password

  extra_disk_storage = "additional-storage" # Name of the Proxmox storage
  extra_disk_size    = "10G"
}
