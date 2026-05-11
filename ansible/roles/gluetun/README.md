# Ansible Role: Gluetun

> **LEGACY — Docker only.** This role is no longer used for new deployments. Gluetun has been migrated to Kubernetes (K3s) as a sidecar container alongside qBittorrent. See `kubernetes/arr/04-qbittorrent-deployment.yaml` and `MIGRATION-PLAN.md`.

This role deploys and configures the [Gluetun VPN container](https://github.com/qdm12/gluetun) using Docker.

This role creates the container with the appropriate VPN settings and exposes ports for other services (e.g., the ARR stack).

## Table of Contents

-   [Requirements](#requirements)
-   [Role Variables](#role-variables)
    -   [Container Settings](#container-settings)
    -   [Exposed Ports](#exposed-ports)
    -   [Volume](#volume)
    -   [VPN Settings](#vpn-settings)
-   [Usage](#usage)

## Requirements

-   Docker Engine and Docker Compose v2 on the target host.

## Role Variables

### Container Settings

These variables define the base container properties used when deploying Gluetun.

```yaml
gluetun_docker_container_name: gluetun
gluetun_docker_image: qmcgaw/gluetun
gluetun_docker_image_version: latest
```

### Exposed Ports

These variables expose application ports through the Gluetun container. They allow other containers running in the same network namespace (e.g., `network_mode: "container:gluetun"`) to be reachable through Gluetun’s network interface.

```yaml
gluetun_docker_port_qbittorrent_ui: 8081
gluetun_docker_port_qbittorrent: 6881
gluetun_docker_port_qbittorrent_udp: 6881
gluetun_docker_port_prowlarr: 9696
gluetun_docker_port_radarr: 7878
gluetun_docker_port_sonarr: 8989
gluetun_docker_port_flaresolverr: 8191
```

### Volume

This variable defines the directory on the host where Gluetun stores its persistent configuration.

```yaml
gluetun_directory: /opt/gluetun
```

### VPN Settings

These variables configure the VPN connection for Gluetun. You must set them to connect successfully to your VPN provider.

This role supports both WireGuard and OpenVPN. See the [Gluetun documentation](https://github.com/qdm12/gluetun/wiki) for a list of supported providers and their specific settings.

```yaml
gluetun_vpn_service_provider:
gluetun_vpn_type: openvpn # or wireguard
gluetun_openvpn_user:
gluetun_openvpn_password:
gluetun_wireguard_private_key:
gluetun_wireguard_addresses:
```

## Usage

### Minimal Playbook

```yaml
- hosts: media-servers
  become: true
  roles:
    - role: install-docker
    - role: gluetun
```