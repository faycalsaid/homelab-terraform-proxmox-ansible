# Proxmox Setup with Cloud-Init and External Storage

This document explains how to prepare Proxmox VE for automated VM deployment using **Cloud-Init templates** and how to **add external storage** for use with VMs or backups.


## Table of Contents
- [Create an Ubuntu Cloud-Init Template](#create-an-ubuntu-cloud-init-template)
- [Add External Disk as Proxmox Storage](#add-external-disk-as-proxmox-storage)
- [Troubleshooting](#troubleshooting)
    - [VM fails to start: "volume 'storage:VMID/disk.raw' does not exist"](#vm-fails-to-start-volume-storagevmiddiskraw-does-not-exist)
    - [External USB disk disconnected (dock bumped / power cycled)](#external-usb-disk-disconnected-dock-bumped--power-cycled)
    - [Your external disk was unplugged or replugged, device name changed](#your-external-disk-was-unplugged-or-replugged-device-name-changed)

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

## VM fails to start: "volume 'storage:VMID/disk.raw' does not exist"

This happens when a VM references a disk on an external storage, but Proxmox cannot find the volume. There are **two possible causes** — check them in order.

**Example error:**
```
TASK ERROR: volume '<your-storage>:<VMID>/vm-<VMID>-disk-0.raw' does not exist
```

### Step 1: Check if the storage is mounted at all

```bash
mount | grep <your-mount-point>
df -h | grep <your-mount-point>
```

**If the storage is NOT mounted** → the problem is the underlying disk, not the VM config. Jump to:
- [External USB disk disconnected (dock bumped / power cycled)](#external-usb-disk-disconnected-dock-bumped--power-cycled)
- [External disk unplugged or device name changed](#your-external-disk-was-unplugged-or-replugged-device-name-changed)

**If the storage IS mounted** → continue below, the VM config reference is broken.

### Step 2: Confirm the disk file physically exists

```bash
ls -lh <your-mount-point>/images/<VMID>/
```
You should see the `.raw` file (e.g. `vm-<VMID>-disk-0.raw`).

### Step 3: Check the VM config

```bash
qm config <VMID> | grep -E "scsi|virtio|ide|unused"
```
If the disk slot (e.g. scsi1) is missing, or the disk shows up as `unused0`, that confirms the issue.

### How to fix it ?

Reattach the existing disk to the VM:
```bash
# Reattach the disk (adjust slot, storage name, VMID and disk name as needed)
qm set <VMID> --scsi1 <your-storage>:<VMID>/vm-<VMID>-disk-0.raw

# Rescan the VM to pick up the change
qm rescan --vmid <VMID>
```

If the Cloud-Init drive was also removed, re-add it:
```bash
qm set <VMID> --ide2 local-lvm:cloudinit
```

Then start the VM:
```bash
qm start <VMID>
```

> ⚠️ **Root cause:** This typically happens when Terraform tries to update a VM that has a disk on renamed storage. The old storage name no longer matches, Terraform taints the resource, and the disk gets detached. The data is **not lost** — only the VM config reference is broken.

---

## External USB disk disconnected (dock bumped / power cycled)

If your external HDD is connected via a USB docking station and you accidentally bump it or power-cycle the dock while Proxmox is running, the disk disconnects. After reconnecting, the mount is lost and the VM can't find its disk.

**Proxmox UI may show the storage as "Active"** but with a suspiciously small size (e.g. your root FS size instead of the external disk size) — that's because the mount point directory still exists on the root filesystem, but the external disk is no longer mounted there.

**Example symptoms:**
```
TASK ERROR: volume '<your-storage>:<VMID>/vm-<VMID>-disk-0.raw' does not exist
```
```bash
mount | grep <your-mount-point>                  # returns nothing — disk is NOT mounted
ls <your-mount-point>/images/<VMID>/             # empty — you're seeing root fs, not the disk
```

### How to confirm this exact issue ?

1. Check the disk is detected but not mounted:
   ```bash
   lsblk                              # your disk should be visible with no MOUNTPOINT
   mount | grep <your-mount-point>    # should return nothing
   ```

2. Check the disk has a valid filesystem:
   ```bash
   blkid /dev/sdX
   # Should show: UUID="..." TYPE="ext4" (or your filesystem type)
   ```

3. The Proxmox storage directory exists but is empty (sitting on root fs):
   ```bash
   ls <your-mount-point>/images/<VMID>/
   # Empty or "No such file or directory"
   ```

### How to fix it ?

1. **Mount the disk:**
   ```bash
   mount -t ext4 /dev/sdX <your-mount-point>
   ```
   > Check `blkid` output to know whether the filesystem is on `/dev/sdX` directly or on a partition like `/dev/sdX1`.

2. **Verify the disk files are back:**
   ```bash
   ls -lh <your-mount-point>/images/<VMID>/
   # Should show: vm-<VMID>-disk-0.raw
   df -h | grep <your-mount-point>
   # Should now show the real disk size
   ```

3. **Start the VM** (from Proxmox UI or CLI):
   ```bash
   qm start <VMID>
   ```

That's it. The data is never lost — the disk just needs to be remounted.

### Why does this happen ?

Linux does **not** auto-remount USB disks after a disconnect/reconnect. `fstab` only runs at boot (`mount -a`). So when the dock gets bumped:
1. Disk disconnects → Linux drops the mount
2. Dock recovers → disk reappears as `/dev/sdX`
3. But nobody calls `mount` → the mount point stays empty
4. Proxmox still sees the storage as "Active" because the **directory** exists — it just shows root FS free space

**Another common cause:** If you previously swapped the physical disk but forgot to update the UUID in `/etc/fstab`, the disk will **never** auto-mount on boot — `mount -a` silently fails because the old UUID doesn't exist anymore. The `nofail` option lets boot continue without error, hiding the problem until a VM tries to access the storage.

**Always verify after a disk swap:**
```bash
blkid /dev/sdX               # actual UUID on the disk
grep <your-mount-point> /etc/fstab   # UUID fstab expects
# If they don't match → update fstab with the real UUID
```

> 💡 **Quick debug:** `mount | grep <your-mount-point>` — if empty, just remount and start the VM.

> 💡 **Prevention:** Secure the USB docking station so it can't be accidentally bumped.

---

## Your external disk was unplugged or replugged, device name changed

### How to confirm this exact issue ?
Check if two devices are mounted on the same folder:
```bash
mount | grep <your-mount-point>
```

❌ BAD (double mount)
```bash
/dev/sda1 on <your-mount-point>
/dev/sdd1 on <your-mount-point>
```

✅ GOOD (only one)
```bash
/dev/sdd1 on <your-mount-point>
```

### How to fix it ?
Unmount both layers:
```bash
umount -f <your-mount-point>
umount -f /dev/sda1 2>/dev/null
umount -f /dev/sdd1 2>/dev/null
```

Remove stale kernel mount reference:
```bash
umount -l /dev/sda1 2>/dev/null
```

Remount all from fstab:
```bash
mount -a
```

Verify only one device is mounted (✅ Should show only one device now):
```bash
mount | grep <your-mount-point>
```



