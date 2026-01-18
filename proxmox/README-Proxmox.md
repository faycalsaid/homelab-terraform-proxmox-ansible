# Proxmox Setup with Cloud-Init and External Storage

This document explains how to prepare Proxmox VE for automated VM deployment using **Cloud-Init templates** and how to **add external storage** for use with VMs or backups.

## Proxmox Version

- **Current Version:** Proxmox VE 9.x

## Table of Contents
- [Create an Ubuntu Cloud-Init Template](#create-an-ubuntu-cloud-init-template)
- [Add External Disk as Proxmox Storage](#add-external-disk-as-proxmox-storage)
- [Troubleshooting](#troubleshooting)
    - [Your external disk was unplugged or replugged, device name changed](#your-external-disk-was-unplugged-or-replugged-device-name-changed)
        - [How to confirm this exact issue ?](#how-to-confirm-this-exact-issue-)
        - [How to fix it ?](#how-to-fix-it-)

# Create an Ubuntu Cloud-Init Template

Cloud images (.img or .qcow2) support automatic provisioning via Cloud-Init. This template will be used as the base for all Terraform-created VMs.

**Follow these steps on your Proxmox VE host:**

- Download Ubuntu Cloud Image

```bash
wget -P /var/lib/vz/template/iso/ https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

- Create a Base VM
```bash
qm create 1000 --name "ubuntu-24.04-cloud-init-template" --memory 1024 --net0 virtio,bridge=vmbr0
```

- Import the cloud image as a disk
```bash
qm importdisk 1000 /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img local-lvm
```

- Set Boot Disk and Controller, we configure this storage to be of the desired type and assign it as a boot volume:
```bash
qm set 1000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-1000-disk-0
qm set 1000 --boot c --bootdisk scsi0
```

- Add Cloud-Init Drive (Virtual CD-ROM), so that Proxmox cloud-init configuration can be read by the VM. It creates a vritual cdrom and attach it to the vm
```bash
qm set 1000 --ide2 local-lvm:cloudinit
```

- Enable Serial Console (Recommended), to be able to see the cloud-init output during boot
```bash
    qm set 1000 --serial0 socket --vga serial0
```

- Configure Cloud-Init Default User  (It'll be overridden by terraform later)
```bash
qm set 1000 --ciuser serveradmin --cipassword serveradmin
```

- Add SSH Public Key for Passwordless Login (Also overridden by terraform later)
```bash
qm set 1000 --sshkey <(echo "ssh-ed25519 AAAAC3--------------------------------77 john.doe)
```

- Convert the VM to a template
```bash
qm template 1000
```

You now have a reusable Cloud-Init template that Terraform will clone!


# Add External Disk as Proxmox Storage

To add an external disk as storage in Proxmox VE, **follow these steps**:

1. Plug in the external disk to your Proxmox VE server.
2. **Identify the Disk**: First, identify the disk you want to add. You can use the `lsblk` or `fdisk -l` command to list all available disks and their partitions.
3. Wipe the disk (optional but recommended if the disk has existing partitions):
   ```bash
   wipefs -a /dev/sdX
   ```
   Replace `/dev/sdX` with your actual disk identifier.
4. **Create GPT Partition Table**:
    ```bash
    fdisk /dev/sdX
    ```
   - Then follow this sequence of commands:
      - g   (create GPT)
      - n   (create partition 1)
      - Enter (Partition number 1 default)
      - Enter (default first sector)
      - Enter (Last sector (default full size)	Use whole disk)
      - w   (write changes)


5. **Format the Partition**: Format the new partition with a filesystem (e.g., ext4):
   ```bash
   mkfs.ext4 /dev/sdX1
   ```
   Replace `/dev/sdX1` with your actual partition identifier.
6. **Create a Mount Point**: Create a directory where the disk will be mounted:
   ```bash
      mkdir /mnt/additional-storage
   ```
7. Add to /etc/fstab (Auto-mount on Boot)

   - Get the UUID of the partition:
      ```bash
      blkid /dev/sdX1
      ```
   - Edit `/etc/fstab` to add an entry for the new storage:
      ```bash
      nano /etc/fstab
      ```
   -  Add the following line:
       ```bash
       UUID=your-uuid-here /mnt/additional-storage ext4 defaults,nofail 0 2
        ```
   - Mount and reload daemon to apply changes:
     ```bash
     mount -a
     systemctl daemon-reload
      ```
   - Verify the disk is mounted:
      ```bash
      df -h
      ```

8. **Add Storage in Proxmox VE GUI**:
   - Log in to the Proxmox VE web interface.
   - Navigate to `Datacenter` -> `Storage`.
   - Click on `Add` and select the appropriate storage type (e.g., Directory).
   - Fill in the details:
     - ID: A name for the storage.
     - Directory: The mount point you created (e.g., `/mnt/additional-storage`).
     - Content: Select the types of content you want to store (e.g., VZDump backup file, ISO image, Container template, etc.).
   - Click `Add` to save the new storage configuration.

✅ What You Can Now Do now ? :

Add a new virtual disk to any VM from this storage (with only the size you choose).

Store backups or ISO images on it.

Use it for multiple VMs.
    

# Troubleshooting

## Your external disk was unplugged or replugged, device name changed

### How to confirm this exact issue ?
Check if two devices are mounted on same folder (replace additional-storage with your mount folder name)
```bash
mount | grep additional-storage
```

❌ BAD (double mount)
```bash
/dev/sda1 on /mnt/additional-storage
/dev/sdd1 on /mnt/additional-storage
```

✅ GOOD (only one)
```bash
/dev/sdd1 on /mnt/additional-storage
```

### How to fix it ?
Unmount both layers
```bash
umount -f /mnt/additional-storage
umount -f /dev/sda1 2>/dev/null
umount -f /dev/sdd1 2>/dev/null
```

Remove stale kernel mount reference
```bash
umount -l /dev/sda1 2>/dev/null
```

Remount all from fstab
```bash
mount -a
```

You should now have only one device mounted on the folder (✅ Should show only one device now.)
```bash
mount | grep additional-storage
```




