# Terraform for Proxmox

This directory contains Terraform configurations to create and manage the Proxmox VMs, networks, and storage.

## Directory Structure

-   `environments/`: Contains the environment-specific configurations (e.g., `prod`, `test`).
-   `modules/`: Contains reusable Terraform modules (e.g., for creating a Proxmox VM).

## Getting Started

This guide explains how to use Terraform to provision VMs on Proxmox.

### Prerequisites

-   You must first set up Proxmox with a Cloud-Init template. See the [Proxmox README](../proxmox/README-Proxmox.md) for instructions.
-   Create a `terraform.tfvars` file in the desired environment directory (e.g., `environments/prod/`). You can use `terraform.tfvars.example` as a template.

### Deploying the Infrastructure

1.  **Initialize the Terraform project:**

    Run the following commands from the environment directory (e.g., `environments/prod/`):

    ```bash
    terraform init
    terraform validate
    ```

2.  **Plan and apply the configuration:**

    Always run `terraform plan` to preview changes before applying them.

    ```bash
    terraform plan
    terraform apply
    ```

    To target a specific resource, use the `-target` flag. For example, to plan only the bastion VM:

    ```bash
    terraform plan -target=module.k3s-ubuntu-test.proxmox_vm_qemu.vm-cloudinit
    ```

## Disaster Recovery

In case of a disaster, you need to configure Proxmox to allow the Terraform provider to create and manage resources.

### 1. Create a Proxmox API User

Create a Proxmox user with the required privileges for Terraform.

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt SDN.Use"
pveum user add terraform-prov@pve --password <password>
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

### 2. Create a Linux User for Snippets Upload

Create a Linux user on the Proxmox host to upload Cloud-Init snippets.

```bash
sudo adduser terraform-ssh
chown -R root:www-data /var/lib/vz/snippets
chmod 775 /var/lib/vz/snippets
usermod -aG www-data terraform-ssh
```

### 3. Set Environment Variables

Set the following environment variables for Proxmox provider authentication:

```bash
export PM_USER="terraform-prov@pve"
export PM_PASS="<password>"
```

## Importing Existing Infrastructure

If you have existing VMs that you want to manage with Terraform, you can import them.

To import a VM, use the `terraform import` command. The syntax is:

```bash
terraform import <terraform_resource_address> <proxmox_vm_id>
```

For example, to import a VM with ID `100` into the `media_vm` module:

```bash
terraform import module.media_vm.proxmox_vm_qemu.vm 100
```

After importing, run `terraform plan` to see the difference between the imported resource and the configuration.

To get the configuration of an existing VM in JSON format, you can use `pvesh`:

```bash
pvesh get /nodes/pve/qemu/100/config --output-format json-pretty
```