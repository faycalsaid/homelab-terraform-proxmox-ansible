# Ansible Role: Base Storage

> **LEGACY — Docker / VM 101 only.** This role is no longer used for K3s deployments. On VM 102 (K3s), the USB disk is mounted manually via `/etc/fstab` and exposed to Kubernetes via a hostPath PersistentVolume. See `kubernetes/arr/02-arr-data-pv.yaml` and `MIGRATION-PLAN.md`.

This role formats and mounts an external disk on a VM, then persists the mount in `/etc/fstab`.
