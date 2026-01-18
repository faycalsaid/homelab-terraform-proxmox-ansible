terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

/* Configure Cloud-Init User-Data with custom config file */
resource "local_file" "cloud_init_user_data_file" {
  content = templatefile(
    var.is_ansible_runner ? "${path.module}/cloudinit-runner.tftpl" : "${path.module}/cloudinit-receiver.tftpl",
    {
      ansible_public_key      = var.ansible_public_key
      ansible_private_key     = var.ansible_private_key
      server_admin_public_key = var.server_admin_public_key
  })
  filename = "${path.module}/user-data-${var.name}.cfg"
}

# Upload cloud-init user-data to Proxmox via SSH (Terraform has no native resource for snippets)
resource "null_resource" "cloud_init_config_files" {
  # Establish SSH connection to Proxmox VE server to upload the cloud-init snippet
  connection {
    type     = "ssh"
    user     = var.pve_user
    password = var.pve_password
    host     = var.pve_host
  }

  # Upload the snippets in to the folder in the local storage in the Proxmox VE server.
  provisioner "file" {
    source      = local_file.cloud_init_user_data_file.filename
    destination = "/var/lib/vz/snippets/user-data-${var.name}.yml"
  }

  # Reupload if template changes
  triggers = {
    content_hash = local_file.cloud_init_user_data_file.content_sha1
  }
}

resource "proxmox_vm_qemu" "vm-cloudinit" {
  timeouts {
    create = "10m"
  }

  depends_on = [
    null_resource.cloud_init_config_files,
  ]

  vmid        = var.vmid
  name        = var.name
  target_node = var.target_node
  agent       = 1
  cpu {
    cores   = var.cores
    sockets = var.sockets
    type    = "x86-64-v2-AES"
  }

  memory           = var.memory
  boot             = "order=scsi0"                      # Has to be the same as the OS disk of the template
  clone            = "ubuntu-24.04-cloud-init-template" # The name of the template
  scsihw           = "virtio-scsi-single"
  automatic_reboot = true
  tablet           = var.tablet

  # Cloud-Init configuration
  ci_wait    = 60
  cicustom   = "user=local:snippets/user-data-${var.name}.yml"
  nameserver = "1.1.1.1 8.8.8.8"
  os_type    = "cloud-init"
  ipconfig0  = var.ipconfig0
  skip_ipv6  = true

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        # We have to specify the same disk from our template, else Terraform will think it's not supposed to be there
        disk {
          storage = "local-lvm"
          # The size of the disk should be at least as big as the disk in the template. If it's smaller, the disk will be recreated
          size = var.disk_size
        }
      }
      dynamic "scsi1" {
        # Only add an extra disk if both storage and size are provided
        for_each = var.extra_disk_storage != null && var.extra_disk_size != null ? [1] : []
        content {
          disk {
            storage = var.extra_disk_storage
            size    = var.extra_disk_size
          }
        }
      }
    }

    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      # Here we do like the template
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }
}


