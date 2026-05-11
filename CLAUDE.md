# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Collaboration style

The user runs all commands themselves. Claude's role is to explain **why** a step is needed, **what** it does, and **how** it works — then provide the command for the user to execute. Never apply, run, or execute infrastructure changes autonomously.

## Big picture

Three-layer IaC for a single-host Proxmox homelab on a 16GB mini PC. Each layer feeds the next:

1. **Proxmox** (`proxmox/`) — bare host. A Cloud-Init Ubuntu 24.04 template (VMID 1000) is built once by hand and is the parent for every VM Terraform spawns.
2. **Terraform** (`terraform/`) — clones the template into the four production VMs. Per-VM cloud-init user-data is rendered from `cloudinit-runner.tftpl` (bastion only, includes Ansible private key) or `cloudinit-receiver.tftpl` (everyone else), then SCP'd to `/var/lib/vz/snippets/` on the Proxmox host via `null_resource` because the Telmate provider has no native snippet resource.
3. **Ansible** (`ansible/`) and **Kubernetes manifests** (`kubernetes/`) — configure the VMs. Ansible owns the legacy Docker stack and bootstraps K3s; the K8s manifests are the target state.

The fixed VM topology (defined in `terraform/environments/prod/main.tf` and mirrored in `ansible/inventory/homelab.yml`):

| VMID | Name | IP | Role |
|---|---|---|---|
| 100 | bastion-ubuntu-prod | .160 | Ansible runner + jump box (Docker: monitoring, homepage) |
| 101 | media-ubuntu-prod | .161 | Legacy Docker VM — Arr stack decommissioning in progress, no extra disk |
| 102 | k3s-ubuntu-prod | .162 | K3s single-node — 470GB USB disk at `/opt/data` (manually mounted, not Ansible) |
| 103 | openclaw-ubuntu-prod | .163 | OpenClaw AI assistant |

The bastion is special: Terraform generates an ED25519 keypair at apply time and injects the **private** key into bastion's cloud-init only. From there `ansible` user SSHes to the other VMs using the matching public key.

## Active migration: Docker → K3s

The repo is mid-migration from Docker (Ansible-managed on VM 101) to K3s (VM 102). See `MIGRATION-PLAN.md` and `PROGRESS.md` for the live tracker. Key invariants from the migration plan:

- **Single-root data path**: All Arr apps must see `/opt/data` as the data root. Don't introduce per-app paths — atomic moves between qBittorrent and Radarr/Sonarr depend on this.
- **K8s storage is via hostPath PV**, not Ansible. The 470GB USB disk is mounted at `/opt/data` on VM 102 via `/etc/fstab` (manual, one-time). The Ansible `base-storage` role is legacy (Docker/VM 101 only).
- **K8s namespaces** are pre-created in `kubernetes/namespaces.yaml`: `homepage`, `monitoring`, `media`. Apply this first.
- **Legacy Ansible roles**: `arr-stack`, `gluetun`, `base-storage` are Docker-only and apply to VM 101 only. They are being decommissioned. Do not use them for K3s workloads.

## Common commands

### Terraform (run from `terraform/environments/prod/` or `.../test/`)

```bash
terraform init
terraform plan
terraform apply
# Target one VM:
terraform plan -target=module.k3s-ubuntu-prod.proxmox_vm_qemu.vm-cloudinit
```

Auth is via env vars, not tfvars: `export PM_USER="terraform-prov@pve"; export PM_PASS="..."`. The provider is pinned to `Telmate/proxmox 3.0.2-rc07` (an RC — do not bump casually).

### Ansible (run from `ansible/`)

`ansible.cfg` sets `inventory = ./inventory/homelab.yml` and `become = true` — no need to pass `-i`.

```bash
# Install collections (includes git-sourced k3s and openclaw collections)
ansible-galaxy collection install -r requirements.yml

# Legacy Docker stack (bastion + media VMs). Vault-encrypted secrets in group_vars.
ansible-playbook ./playbooks/site.yml --ask-vault-pass

# K3s single-node bootstrap (delegates to k3s.orchestration.site)
ansible-playbook ./playbooks/k3s.yml

# OpenClaw VM
ansible-playbook ./playbooks/openclaw.yml

# Docker-only on a single host
ansible-playbook ./playbooks/docker.yml --limit <host>

# Encrypt a secret inline for group_vars
ansible-vault encrypt_string --ask-vault-pass "secret" --name "var_name"
```

### Kubernetes (against the K3s context `homelab-k3s`)

```bash
kubectl apply -f kubernetes/namespaces.yaml
kubectl apply -f kubernetes/homepage/   # ordered 01..07 by filename
```

`07-credentials.yaml` is gitignored / not committed cleanly — use `07-credentials.yaml.example` as the template and create the secret out-of-band.

## Repo-specific gotchas

- **Jinja in `group_vars` is not auto-rendered.** Variables like `media_host: '{{ hostvars["media-01"].ansible_host }}'` won't resolve unless the playbook explicitly re-loads the vars file with `include_vars` in `pre_tasks`. `site.yml` already does this for all groups; any new playbook that relies on cross-group var references must do the same. Don't "fix" this by inlining values.
- **`baseline-security`, `tailscale`, `helm` Ansible roles are referenced but commented out** in `playbooks/k3s.yml` (TODO). They don't exist yet — don't import them blindly.
- **K3s deploy is fully delegated** to `k3s.orchestration.site` from the upstream `k3s-io/k3s-ansible` collection (pinned to `1.1.1` in `requirements.yml`). The repo has no local K3s role.
- **Vault password is required for `site.yml`** — `bastion-servers.yml` and `media-servers.yml` contain `!vault` blocks (Proxmox API password, Mullvad WireGuard private key). `k3s.yml` and `openclaw.yml` currently do not need vault.
- **Terraform state is local and committed** (`*.tfstate` is in the gitignore for `terraform/.gitignore`, but `tfvars` files containing secrets are also gitignored — use the `.example` files). Do not commit `terraform.tfvars`.
- **Disk recreation trap**: in `modules/proxmox-vm-ubuntu-24-cloudinit/main.tf`, `disk_size` must be ≥ the template's disk size or Terraform will recreate the disk. The extra-disk block is conditional on both `extra_disk_storage` and `extra_disk_size` being set.
- **External USB storage is fragile.** `proxmox/README-Proxmox.md` has the full troubleshooting playbook for the "volume does not exist" / disconnected-dock failure modes. Read it before debugging missing-disk errors — the data is almost never lost, just the mount.

## Where to look first

- Adding/changing a VM → `terraform/environments/prod/main.tf` + `ansible/inventory/homelab.yml` (keep IPs and VMIDs in sync).
- New Ansible service for the Docker stack → add a role under `ansible/roles/`, wire it into `playbooks/site.yml`.
- New K8s workload → follow the numeric-prefix convention used in `kubernetes/homepage/` (`01-rbac` → `02-secret` → `03-configmap` → `04-deployment` → `05-service` → `06-ingress`).
- Per-service config and secrets → `ansible/inventory/group_vars/<group>.yml` (vault-encrypt secrets inline).
