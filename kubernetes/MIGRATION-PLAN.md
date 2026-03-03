# Docker to K3s Migration Plan

> **Date:** March 2026
> **Status:** In Progress
> **Goal:** Migrate existing Docker-based services to K3s and install ClawdBot

## Current State

| VM | Role | IP | Services |
|---|---|---|---|
| bastion-ubuntu-prod (100) | Docker host | 192.168.1.160 | Homepage, Grafana, Prometheus, cAdvisor |
| media-ubuntu-prod (101) | Docker host | 192.168.1.161 | Gluetun (Mullvad VPN), Radarr, Sonarr, Prowlarr, qBittorrent, Jellyfin, Jellyseerr, FlareSolverr, cAdvisor |
| k3s-ubuntu-prod (102) | K3s cluster | 192.168.1.162 | Fresh K3s v1.35.0+k3s1 — nothing deployed yet |

**Storage:** 300GB external USB HDD attached to VM 101 via Proxmox (`vm-storage-new`), mounted at `/opt/data`

## Target State

All services running on K3s (VM 102). Docker VMs either decommissioned or repurposed.

```
kubernetes/
├── namespaces.yaml
├── clawdbot/
│   ├── openclawinstance.yaml  # OpenClaw Operator CR
│   └── secret.yaml
├── homepage/
│   └── values.yaml          # Helm
├── monitoring/
│   └── values.yaml          # Helm (kube-prometheus-stack)
└── media/
    ├── gluetun-arr-pod.yaml  # Gluetun sidecar + arr apps
    ├── jellyfin.yaml
    ├── jellyseerr.yaml
    └── storage.yaml          # PV + PVC for media data
```

---

## Phase 0 — Foundation & Learning

- [ ] Learn kubectl basics (`get`, `describe`, `logs`, `apply`, `delete`)
- [ ] Understand core concepts: Pods, Deployments, Services (ClusterIP/NodePort), ConfigMaps, Secrets, Namespaces
- [ ] Install Helm on the K3s node
- [ ] Create `kubernetes/` directory structure in the repo
- [ ] Create namespaces (`clawdbot`, `homepage`, `monitoring`, `media`)
- [ ] Harden K3s VM for ClawdBot (see [Securing ClawdBot](#securing-clawdbot) below)

**No migration yet — just setup and practice.**

---

## Repository Strategy

**Everything stays in the same repo.** No need for a new repo or branch — Docker and K3s configs coexist:

```
homelab/
├── ansible/           # Docker VM configuration (stays until Phase 5)
│   └── roles/         # arr-stack, monitoring, homepage, etc.
├── kubernetes/        # K3s manifests (added progressively from Phase 1)
│   ├── clawdbot/
│   ├── homepage/
│   └── ...
└── terraform/         # Provisions ALL VMs (Docker + K3s)
```

- **During migration:** both `ansible/` and `kubernetes/` are active — they target different VMs
- **After migration:** Ansible roles for Docker VMs become unused but **stay in git history forever**
- **To see the old Docker setup:** just `git log` / `git show` — no rollback needed
- **To rollback a service to Docker:** re-run the Ansible playbook against the Docker VM — the roles are still there until you delete them

> 💡 Only remove Ansible Docker roles from the repo **after** all services are validated on K3s and you're confident in the migration.

---

## Securing ClawdBot

> **Reference:** [ClawdBot: Setup Guide + How to NOT Get Hacked](https://medium.com/@lukasniessen) — Lukas Niessen, Jan 2026
>
> ClawdBot is an AI assistant with shell access, API tokens, and messaging app connectivity. If misconfigured, it exposes your server to the internet. Many public instances run with zero authentication and world-readable credentials. **Security is not optional.**

### What the OpenClaw Operator handles for you

The [K8s operator](https://github.com/openclaw-rocks/k8s-operator) applies these by default — no configuration needed:

- ✅ Non-root execution (UID 1000), root blocked by validating webhook
- ✅ Read-only root filesystem
- ✅ All Linux capabilities dropped
- ✅ Seccomp RuntimeDefault
- ✅ Default-deny NetworkPolicy (only DNS + HTTPS egress, ingress limited to same namespace)
- ✅ Minimal RBAC per instance
- ✅ No automatic SA token mounting (unless self-configure is enabled)
- ✅ Gateway auth token auto-generated (mDNS/Bonjour disabled — doesn't work in K8s)
- ✅ npm lifecycle scripts disabled for skill installs (supply chain attack mitigation)

### What you still need to do manually

#### VM-level hardening (do during Phase 0)

- [ ] **SSH keys only** — disable password auth and root login on the K3s VM
  ```
  # /etc/ssh/sshd_config
  PasswordAuthentication no
  PermitRootLogin no
  ```
- [ ] **Default-deny firewall** — block all incoming, allow only what's needed
  ```
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow OpenSSH
  sudo ufw enable
  ```
- [ ] **Brute-force protection** — install and enable `fail2ban`
- [ ] **Install Tailscale** — private mesh VPN so nothing is exposed publicly
- [ ] **SSH only via Tailscale** — remove public SSH rule, allow only from `100.64.0.0/10`
  ```
  sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp
  sudo ufw delete allow OpenSSH
  ```
- [ ] **Web ports private too** — K3s services only accessible via Tailscale
  ```
  sudo ufw allow from 100.64.0.0/10 to any port 443 proto tcp
  sudo ufw allow from 100.64.0.0/10 to any port 80 proto tcp
  ```

#### Application-level config (do during Phase 1)

- [ ] **Lock to owner only** — set in the OpenClawInstance CR config:
  ```yaml
  config:
    raw:
      dmPolicy: allowlist
      allowFrom: ["<your-telegram-or-discord-id>"]
      groupPolicy: allowlist
  ```
  > ⚠️ **Never add ClawdBot to group chats.** Every person in that chat can issue commands to your server through the bot.

- [ ] **Enable sandbox mode** — set `sandbox: true` in the CR config (risky operations run isolated)
- [ ] **Whitelist commands** — only allow what the bot needs, block destructive commands
  ```yaml
  config:
    raw:
      allowedCommands: ["git", "npm", "curl"]
      blockedCommands: ["rm -rf", "sudo", "chmod"]
  ```
- [ ] **Scope API tokens** — minimum permissions, read-only where possible
- [ ] **Run security audit** after deployment:
  ```
  kubectl exec -n clawdbot clawdbot-0 -- clawdbot security audit --deep
  ```

### Prompt injection warning

> A real-world incident: someone sent a crafted email to an account ClawdBot had access to. The email contained hidden instructions. ClawdBot followed them and **deleted all emails including trash**. This is not theoretical.

Mitigations (layered defense):
1. **Use Claude Opus 4.5** — specifically trained to resist prompt injection (~99% resistance in internal testing)
2. **Command whitelisting** — even if the AI is tricked, it can only run approved commands
3. **Sandbox mode** — risky operations are isolated
4. **Scoped API tokens** — limits the damage any single compromised token can do
5. **Operator's default-deny NetworkPolicy** — limits what the container can reach even if compromised

### Verification checklist

After setup, verify everything:
```
# On the VM
sudo ufw status                                              # No public ports
ss -tulnp                                                    # Only expected listeners
tailscale status                                             # Mesh VPN active

# In the cluster
kubectl get openclawinstances -n clawdbot                    # Phase: Running
kubectl exec -n clawdbot clawdbot-0 -- clawdbot doctor       # All checks green
kubectl get networkpolicy -n clawdbot                        # Default-deny policy exists
```

**Expected result:** No public SSH, no public web ports, server only reachable via Tailscale, bot responds only to you, operator-managed security policies active.

---

## Phase 1 — Deploy ClawdBot via OpenClaw Operator *(new workload, easiest)*

> **Using the [OpenClaw K8s Operator](https://github.com/openclaw-rocks/k8s-operator)** instead of manual manifests. The operator manages security hardening, gateway auth, config rollouts, monitoring, and auto-updates out of the box.

### 1a — Install the operator

- [ ] Install the OpenClaw operator via Helm:
  ```bash
  helm install openclaw-operator \
    oci://ghcr.io/openclaw-rocks/charts/openclaw-operator \
    --namespace openclaw-operator-system \
    --create-namespace
  ```

### 1b — Create Telegram bot & secrets

- [ ] Create Telegram bot via `@BotFather`, get token and your user ID from `@userinfobot`
- [ ] Create K8s Secret with API keys:
  ```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name: openclaw-api-keys
    namespace: clawdbot
  type: Opaque
  stringData:
    ANTHROPIC_API_KEY: "sk-ant-..."
  ```

### 1c — Deploy an OpenClaw instance

- [ ] Create `kubernetes/clawdbot/openclawinstance.yaml`:
  ```yaml
  apiVersion: openclaw.rocks/v1alpha1
  kind: OpenClawInstance
  metadata:
    name: clawdbot
    namespace: clawdbot
  spec:
    envFrom:
      - secretRef:
          name: openclaw-api-keys
    config:
      raw:
        agents:
          defaults:
            model:
              primary: "anthropic/claude-sonnet-4-20250514"
            sandbox: true
        dmPolicy: allowlist
        allowFrom: ["<your-telegram-id>"]
        groupPolicy: allowlist
    storage:
      persistence:
        enabled: true
        size: 10Gi
    observability:
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true
    # Tailscale for external access (ties into the hybrid/GCP plan)
    # tailscale:
    #   enabled: true
    #   mode: serve
    #   authKeySecretRef:
    #     name: tailscale-auth
    #   hostname: clawdbot
  ```
- [ ] Deploy: `kubectl apply -f kubernetes/clawdbot/`
- [ ] Verify: `kubectl get openclawinstances -n clawdbot` → should show `Running`

### 1d — Validate

- [ ] Check pod is healthy: `kubectl get pods -n clawdbot`
- [ ] Check logs: `kubectl logs -n clawdbot clawdbot-0`
- [ ] Run doctor: `kubectl exec -n clawdbot clawdbot-0 -- clawdbot doctor`
- [ ] Approve Telegram pairing:
  ```bash
  kubectl exec -n clawdbot clawdbot-0 -- clawdbot pairing list telegram
  kubectl exec -n clawdbot clawdbot-0 -- clawdbot pairing approve telegram <code>
  ```

### What the operator handles automatically (no config needed)

- **Security:** non-root (UID 1000), read-only root FS, all capabilities dropped, seccomp RuntimeDefault, default-deny NetworkPolicy (only DNS + HTTPS egress)
- **Gateway auth:** auto-generated token Secret, mDNS disabled (doesn't work in K8s)
- **Config rollouts:** SHA-256 hash triggers rolling updates on config change
- **Monitoring:** Prometheus metrics + ServiceMonitor ready for Phase 3's `kube-prometheus-stack`

**Why first:** Net-new service, no migration complexity. No ingress needed (Telegram bot connects outbound). The operator reduces Phase 1 to `helm install` + one CR. Perfect first K3s exercise to learn CRDs, Helm, and Secrets.

> 📚 **Docs:** [Operator README](https://github.com/openclaw-rocks/k8s-operator) · [OpenClaw Getting started](https://docs.clawd.bot/start/getting-started) · [Security guide](https://docs.clawd.bot/gateway/security)

---

## Phase 2 — Migrate Homepage

- [ ] Deploy Homepage using its [Helm chart](https://github.com/jameswynn/helm-charts)
- [ ] Translate existing config files (`services.yaml`, `settings.yaml`, `widgets.yaml`, etc.) to ConfigMaps or Helm values
- [ ] Expose via NodePort or Traefik IngressRoute (K3s bundles Traefik)
- [ ] Validate at `http://192.168.1.162:<port>`
- [ ] Stop Homepage container on bastion VM

**Teaches:** Helm, ConfigMaps, Ingress/Services

---

## Phase 3 — Migrate Monitoring

- [ ] Deploy [`kube-prometheus-stack`](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) via Helm
- [ ] Configure PVC for Prometheus + Grafana data persistence (`local-path` StorageClass)
- [ ] During transition: configure scrape targets to also hit Docker VMs' cAdvisor
- [ ] Expose Grafana via NodePort or Traefik ingress
- [ ] Import existing Grafana dashboards
- [ ] Validate metrics collection
- [ ] Remove cAdvisor + Prometheus + Grafana containers from bastion VM

**Note:** K3s kubelet has cAdvisor built-in — no need for a standalone cAdvisor container.

---

## Phase 4 — Migrate Arr Stack + Gluetun VPN *(most complex)*

### 4a — Prepare storage

- [ ] Detach 300GB disk from VM 101 (Terraform: remove `extra_disk_storage` from `media-ubuntu-prod`)
- [ ] Attach 300GB disk to VM 102 (Terraform: add `extra_disk_storage` + `extra_disk_size` to `k3s-ubuntu-prod`)
- [ ] Mount disk inside K3s VM (reuse `base-storage` Ansible role)
- [ ] Create PersistentVolume + PersistentVolumeClaim pointing to the mount (`kubernetes/media/storage.yaml`)

> ⚠️ **Before detaching:** rsync media data from VM 101 to a backup, or plan for downtime since the USB HDD can only attach to one VM at a time.

### 4b — Deploy Gluetun + VPN-routed apps

In Docker you use `network_mode: container:gluetun`. The K8s equivalent is a **sidecar container** in the same Pod (shared network namespace).

- [ ] Create a Pod/Deployment with:
  - **Gluetun** container (with `NET_ADMIN` capability + `/dev/net/tun`)
  - **qBittorrent** container (shares Gluetun's network)
  - **Radarr** container
  - **Sonarr** container
  - **Prowlarr** container
  - **FlareSolverr** container
- [ ] Store Mullvad WireGuard private key as a K8s Secret
- [ ] Expose ports via a K8s Service

### 4c — Deploy non-VPN apps

- [ ] Deploy **Jellyfin** as a separate Deployment + Service (doesn't need VPN)
- [ ] Deploy **Jellyseerr** as a separate Deployment + Service (doesn't need VPN)
- [ ] Both use the shared media PVC

### 4d — Validate & cutover

- [ ] Verify VPN: `kubectl exec` into Gluetun pod → check external IP
- [ ] Verify Radarr/Sonarr → Prowlarr connectivity
- [ ] Verify qBittorrent downloads work
- [ ] Verify Jellyfin can serve media
- [ ] Stop all Docker containers on media VM

---

## Phase 5 — Cleanup & IaC

- [ ] Commit all manifests/Helm values in `kubernetes/`
- [ ] Optionally install **FluxCD** or **ArgoCD** for GitOps (auto-deploy from Git)
- [ ] Consider **Sealed Secrets** or **SOPS + age** for encrypting secrets in Git (replaces ansible-vault)
- [ ] Update Homepage service URLs to point to K3s internal endpoints
- [ ] Optionally decommission bastion + media VMs via Terraform to reclaim resources
- [ ] Update main `README.md` and architecture diagram

---

## Resource Considerations

| Concern | Detail |
|---|---|
| **RAM** | K3s VM has 6GB. Full stack + Jellyfin transcoding may be tight. Monitor and bump in Terraform if needed. |
| **Storage** | USB HDD can only attach to one VM at a time. Keep on VM 101 until Phase 4. |
| **VPN secrets** | Mullvad WireGuard key is currently ansible-vault. For K8s, use Sealed Secrets or SOPS. |
| **Downtime** | Keep Docker VMs running in parallel. Only decommission after validation on K3s. |
| **Gluetun pattern** | Sidecar (all VPN apps in one Pod) is simplest — mirrors `network_mode: container`. Can refactor to proxy pattern later. |

---

## Hybrid Cloud — Adding a GCP K3s Node

### Why hybrid ?

- **Redundancy**: If the homelab goes down (power outage, USB dock bump...), some services stay available
- **External access**: Services on GCP are publicly reachable without VPN or port forwarding
- **Learning**: Experience with multi-node K3s across networks

### Architecture

```
┌─────────────────────────┐         WireGuard tunnel          ┌──────────────────────────┐
│   Home (Proxmox)        │◄────────────────────────────────►  │   GCP                    │
│                         │                                    │                          │
│   k3s-ubuntu-prod       │                                    │   k3s-gcp-agent          │
│   (server / control     │                                    │   (agent / worker node)  │
│    plane)               │                                    │                          │
│   192.168.1.162         │                                    │   <public-ip>            │
└─────────────────────────┘                                    └──────────────────────────┘
```

- **K3s server** stays at home (control plane + most workloads)
- **K3s agent** on GCP joins the cluster over a WireGuard/Tailscale tunnel
- Lightweight services (ClawdBot, Homepage) can run on GCP
- Heavy/storage-dependent services (arr stack, Jellyfin) stay at home

### Steps

- [ ] Provision a GCP VM (e2-small or e2-medium is enough for lightweight workloads)
- [ ] Connect home ↔ GCP via **Tailscale** or **WireGuard** tunnel (so K3s agent can reach the server API on port 6443)
- [ ] Install K3s agent on GCP VM pointing to the home server: `K3S_URL=https://<tailscale-ip>:6443 K3S_TOKEN=<token>`
- [ ] Use **node labels** to control scheduling:
  - `location=home` on the Proxmox node
  - `location=cloud` on the GCP node
- [ ] Use `nodeSelector` or `nodeAffinity` in manifests to pin workloads to the right node
- [ ] Add GCP VM provisioning to Terraform (Google provider)
- [ ] Add GCP node to Ansible inventory under `k3s-cluster.agent`

### What to run where ?

| Service | Node | Why |
|---|---|---|
| Arr stack + Gluetun | Home | Needs 300GB storage + VPN |
| Jellyfin | Home | Needs media storage + transcoding |
| Monitoring (Prometheus/Grafana) | Home | Needs to scrape local services |
| ClawdBot | GCP | Stateless, just needs internet |
| Homepage | GCP or Home | Lightweight, could be either |

---

## External Access — Alternatives to VPN

### Current situation

- Services are only accessible from the **local LAN** (192.168.1.x)
- From outside, you connect via your **GL.iNet travel router** which runs a **WireGuard server** (port already forwarded on home router)
- Once connected to the GL.iNet WireGuard VPN, you get LAN access and can reach all services
- **Limitation:** you need to manually activate the VPN on your device — no direct access otherwise

### Options for external access

#### Option 1: Tailscale *(recommended — easiest)*

[Tailscale](https://tailscale.com/) creates a WireGuard mesh VPN between your devices. Free for personal use (up to 100 devices).

- Install Tailscale on: your phone, laptop, K3s VM, and optionally the GCP node
- Access services via Tailscale IPs (e.g. `http://100.x.y.z:8096` for Jellyfin)
- **No port forwarding, no public exposure, zero config on your router**
- Also solves the home ↔ GCP tunnel for the hybrid K3s setup
- Can share specific services with friends via Tailscale Funnel

```
You (anywhere)  ──tailscale──►  K3s VM (tailscale IP)  ──►  Services
```

#### Option 2: Cloudflare Tunnel *(for public-facing services)*

[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) exposes specific services to the internet behind Cloudflare's network. No port forwarding needed.

- Install `cloudflared` on the K3s node
- Map subdomains to internal services (e.g. `jellyfin.yourdomain.com` → `localhost:8096`)
- Free tier available, includes DDoS protection and SSL
- **Good for**: Jellyfin, Jellyseerr, Homepage — things you want friends/family to access
- **Not recommended for**: admin panels (Radarr, Sonarr, Grafana) unless you add Cloudflare Access (SSO)

```
Anyone (internet)  ──HTTPS──►  Cloudflare  ──tunnel──►  K3s VM  ──►  Services
```

#### Option 3: WireGuard on GL.iNet router *(already in place ✅)*

You already have this running:
- WireGuard server on the GL.iNet router
- Port forwarded on the home router
- Connect from any device with a WireGuard client → full LAN access

**This works fine for personal access.** The main limitations are:
- You need to manually toggle the VPN on/off on each device
- Not practical for sharing services with friends/family (they'd need your WireGuard config)
- Doesn't help for the GCP ↔ Home tunnel (would need a separate WireGuard peer config)

#### Recommendation

| Use case | Solution |
|---|---|
| **You accessing your homelab from anywhere** | GL.iNet WireGuard ✅ (already working) or Tailscale (simpler on mobile) |
| **Friends/family accessing Jellyfin/Jellyseerr** | Cloudflare Tunnel |
| **GCP ↔ Home K3s tunnel** | Tailscale (easier than managing WireGuard peers manually) |

**Your GL.iNet WireGuard setup already covers personal access.** Tailscale becomes useful if you want easier mobile access, or when you add the GCP node (mesh networking without manual peer config). Cloudflare Tunnel is for when you want to share services publicly.

### Steps to add to the plan

- [ ] Create a Tailscale account and install on personal devices
- [ ] Install Tailscale on K3s VM
- [ ] Access services via Tailscale IP from anywhere
- [ ] (Later) Set up Cloudflare Tunnel for public services (Jellyfin, Jellyseerr, Homepage)
- [ ] (Later) Use Tailscale as the home ↔ GCP tunnel for hybrid K3s






