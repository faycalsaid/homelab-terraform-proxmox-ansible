# Ansible Role: K3s Setup

This role configures K3s cluster nodes after installation with SSH lockdown, a default-deny firewall, brute-force protection, [Tailscale](https://tailscale.com/) mesh VPN, and [Helm](https://helm.sh/).

## Table of Contents

-   [Requirements](#requirements)
-   [Role Variables](#role-variables)
    -   [SSH Hardening](#ssh-hardening)
    -   [UFW Firewall](#ufw-firewall)
    -   [fail2ban](#fail2ban)
    -   [Tailscale](#tailscale)
    -   [Helm](#helm)
-   [Usage](#usage)
-   [Post-Run Manual Step](#post-run-manual-step)
-   [Source](#source)

## Requirements

-   Target host must be an **Ubuntu** distribution with K3s already installed.
-   This role is meant to run **after** the `k3s.orchestration.site` playbook (see `playbooks/k3s.yml`).

## Role Variables

### SSH Hardening

Disables password authentication and root login over SSH.

```yaml
ssh_password_authentication: "no"
ssh_permit_root_login: "no"
```

### UFW Firewall

Sets the default firewall policy. Incoming traffic is denied by default, outgoing is allowed.

```yaml
ufw_default_incoming: deny
ufw_default_outgoing: allow
```

### fail2ban

Installs and enables fail2ban for brute-force protection on SSH.

```yaml
fail2ban_enabled: true
```

### Tailscale

Installs Tailscale for remote access when away from home. Does **not** restrict LAN SSH — your private network stays fully accessible.

```yaml
tailscale_enabled: true
tailscale_cidr: "100.64.0.0/10"
```

#### `tailscale_allowed_ports`

Ports allowed from the Tailscale CIDR for remote access. LAN SSH access is always preserved.

```yaml
tailscale_allowed_ports:
  - { port: 22, proto: tcp }    # SSH
  - { port: 80, proto: tcp }    # HTTP
  - { port: 443, proto: tcp }   # HTTPS
  - { port: 6443, proto: tcp }  # K3s API server
```

### Helm

Installs Helm 3 using the official install script.

```yaml
helm_enabled: true
helm_version: ""  # Empty = latest
```

## Usage

This role runs as part of the K3s playbook, after K3s installation:

```yaml
- hosts: k3s-cluster
  become: true
  roles:
    - role: k3s-setup
```

```bash
ansible-playbook playbooks/k3s.yml
```

## Post-Run Manual Step

After the playbook completes, SSH into the K3s node and authenticate Tailscale:

```bash
sudo tailscale up
```

Then approve the device in your [Tailscale admin console](https://login.tailscale.com/admin/machines).

## Source

-   [ClawdBot: Setup Guide + How to NOT Get Hacked — Lukas Niessen](https://lukasniessen.medium.com/clawdbot-setup-guide-how-to-not-get-hacked-63bc951cbd90)
-   [Tailscale documentation](https://tailscale.com/kb)
-   [Helm installation](https://helm.sh/docs/intro/install/)


