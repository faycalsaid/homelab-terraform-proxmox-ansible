# Migration Progress Tracker

> Tracks the execution status of each step from [MIGRATION-PLAN.md](./MIGRATION-PLAN.md).
>
> **Legend:** ⬜ Not started · 🟡 In progress · ✅ Done · ❌ Blocked

---

## Phase 0 — Foundation & Learning

| # | Task | Status | Notes |
|---|---|---|---|
| 0.1 | Learn kubectl basics | ⬜ | |
| 0.2 | Understand core K8s concepts | ⬜ | |
| 0.3 | Install Helm on K3s node | ⬜ | Added to `k3s-setup` Ansible role |
| 0.4 | Create `kubernetes/` directory structure | ⬜ | |
| 0.5 | Create namespaces (clawdbot, homepage, monitoring, media) | ⬜ | |
| 0.6 | Harden K3s VM (SSH, UFW, fail2ban, Tailscale) | ⬜ | Added to `k3s-setup` Ansible role |

### Ansible automation for Phase 0

| Task | How | Status |
|---|---|---|
| SSH hardening | `k3s-setup` role → SSH tasks | ⬜ |
| UFW firewall | `k3s-setup` role → UFW tasks | ⬜ |
| fail2ban | `k3s-setup` role → fail2ban tasks | ⬜ |
| Tailscale install | `k3s-setup` role → Tailscale tasks | ⬜ |
| Tailscale auth (`tailscale up`) | **Manual** — SSH into node after playbook | ⬜ |
| Helm install | `k3s-setup` role → Helm tasks | ⬜ |

**Run:**
1. `ansible-playbook playbooks/k3s.yml -i inventory/homelab.yml` (installs K3s → hardens → installs Helm)
2. SSH into node → `sudo tailscale up` → approve in Tailscale admin console

---

## Phase 1 — Deploy ClawdBot via OpenClaw Operator

| # | Task | Status | Notes |
|---|---|---|---|
| 1a.1 | Install OpenClaw operator via Helm | ⬜ | |
| 1b.1 | Create Telegram bot (@BotFather) | ⬜ | |
| 1b.2 | Create K8s Secret with API keys | ⬜ | |
| 1c.1 | Create `kubernetes/clawdbot/openclawinstance.yaml` | ⬜ | |
| 1c.2 | Deploy with `kubectl apply` | ⬜ | |
| 1c.3 | Verify OpenClawInstance is Running | ⬜ | |
| 1d.1 | Check pod health + logs | ⬜ | |
| 1d.2 | Run `clawdbot doctor` | ⬜ | |
| 1d.3 | Approve Telegram pairing | ⬜ | |
| 1d.4 | Apply security hardening (allowlist, sandbox, whitelist) | ⬜ | |
| 1d.5 | Run `clawdbot security audit --deep` | ⬜ | |

---

## Phase 2 — Migrate Homepage

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | Deploy Homepage Helm chart | ⬜ | |
| 2.2 | Translate config files to ConfigMaps/Helm values | ⬜ | |
| 2.3 | Expose via NodePort or Traefik | ⬜ | |
| 2.4 | Validate at http://192.168.1.162:<port> | ⬜ | |
| 2.5 | Stop Homepage on bastion VM | ⬜ | |

---

## Phase 3 — Migrate Monitoring

| # | Task | Status | Notes |
|---|---|---|---|
| 3.1 | Deploy kube-prometheus-stack via Helm | ⬜ | |
| 3.2 | Configure PVCs for Prometheus + Grafana | ⬜ | |
| 3.3 | Configure scrape targets (include Docker VMs during transition) | ⬜ | |
| 3.4 | Expose Grafana | ⬜ | |
| 3.5 | Import existing Grafana dashboards | ⬜ | |
| 3.6 | Validate metrics collection | ⬜ | |
| 3.7 | Remove monitoring containers from bastion VM | ⬜ | |

---

## Phase 4 — Migrate Arr Stack + Gluetun VPN

### 4a — Storage

| # | Task | Status | Notes |
|---|---|---|---|
| 4a.1 | Detach 300GB disk from VM 101 (Terraform) | ⬜ | |
| 4a.2 | Attach 300GB disk to VM 102 (Terraform) | ⬜ | |
| 4a.3 | Mount disk inside K3s VM (Ansible base-storage role) | ⬜ | |
| 4a.4 | Create PV + PVC (`kubernetes/media/storage.yaml`) | ⬜ | |

### 4b — Gluetun + VPN apps

| # | Task | Status | Notes |
|---|---|---|---|
| 4b.1 | Create Gluetun sidecar Pod/Deployment | ⬜ | |
| 4b.2 | Add qBittorrent, Radarr, Sonarr, Prowlarr, FlareSolverr containers | ⬜ | |
| 4b.3 | Store Mullvad WireGuard key as K8s Secret | ⬜ | |
| 4b.4 | Expose ports via K8s Service | ⬜ | |

### 4c — Non-VPN apps

| # | Task | Status | Notes |
|---|---|---|---|
| 4c.1 | Deploy Jellyfin | ⬜ | |
| 4c.2 | Deploy Jellyseerr | ⬜ | |

### 4d — Validate & cutover

| # | Task | Status | Notes |
|---|---|---|---|
| 4d.1 | Verify VPN (check external IP from Gluetun pod) | ⬜ | |
| 4d.2 | Verify Radarr/Sonarr → Prowlarr connectivity | ⬜ | |
| 4d.3 | Verify qBittorrent downloads | ⬜ | |
| 4d.4 | Verify Jellyfin serves media | ⬜ | |
| 4d.5 | Stop all Docker containers on media VM | ⬜ | |

---

## Phase 5 — Cleanup & IaC

| # | Task | Status | Notes |
|---|---|---|---|
| 5.1 | Commit all manifests/Helm values in `kubernetes/` | ⬜ | |
| 5.2 | (Optional) Install FluxCD or ArgoCD | ⬜ | |
| 5.3 | (Optional) Set up Sealed Secrets or SOPS + age | ⬜ | |
| 5.4 | Update Homepage service URLs | ⬜ | |
| 5.5 | (Optional) Decommission bastion + media VMs | ⬜ | |
| 5.6 | Update README.md and architecture diagram | ⬜ | |

---

## Hybrid Cloud & External Access (future)

| # | Task | Status | Notes |
|---|---|---|---|
| H.1 | Create Tailscale account + install on devices | ⬜ | |
| H.2 | Install Tailscale on K3s VM | ⬜ | Part of `k3s-setup` role |
| H.3 | Provision GCP VM (Terraform) | ⬜ | |
| H.4 | Connect home ↔ GCP via Tailscale | ⬜ | |
| H.5 | Install K3s agent on GCP | ⬜ | |
| H.6 | Set up Cloudflare Tunnel for public services | ⬜ | |

