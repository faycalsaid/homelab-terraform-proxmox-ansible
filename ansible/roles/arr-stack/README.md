# Ansible Role: ARR Media Stack

> **LEGACY — Docker only.** This role is no longer used for new deployments. The Arr stack has been migrated to Kubernetes (K3s). See `kubernetes/arr/` and `MIGRATION-PLAN.md`.

This role deploys and configures the full ARR media automation stack using Docker.

## Table of Contents

-   [Requirements](#requirements)
-   [Role Variables](#role-variables)
    -   [VPN Routing](#vpn-routing)
    -   [Shared Settings](#shared-settings)
    -   [Services](#services)
-   [Usage](#usage)

## Requirements

-   Docker Engine and Docker Compose v2 installed on the target host.
-   (Optional) A separate VPN container (e.g., Gluetun) if you want to use VPN routing. See the [Gluetun role](../gluetun/README.md) for deployment instructions.

## Role Variables

These variables define how the ARR stack containers are deployed, where media and configuration files are stored, and user permissions for mounted volumes.

### VPN Routing

If enabled, all supported containers will use an existing VPN container's network namespace. This is useful to route torrent traffic through a VPN.

```yaml
arr_stack_use_vpn_routing: false
arr_stack_vpn_container_name: "gluetun"
```

### Shared Settings

These settings define host paths and common Docker configurations for all ARR applications.

```yaml
arr_stack_host_dir: /opt/arr-stack
arr_stack_host_shared_data_dir: /opt/data/media
arr_stack_container_data_volume_path: /data
arr_stack_media_user: "media"
arr_stack_media_user_puid: 1000
arr_stack_media_user_pgid: 1000
arr_stack_timezone: "Etc/UTC"
```

### Services

This role can deploy the following services:

-   **Radarr**: A movie collection manager for Usenet and BitTorrent users.
-   **Sonarr**: A TV show collection manager for Usenet and BitTorrent users.
-   **Prowlarr**: An indexer manager for Radarr, Sonarr, and other applications.
-   **qBittorrent**: A torrent client.
-   **Jellyseerr**: A request management and media discovery tool for Jellyfin and Plex.
-   **Jellyfin**: A free and open-source media server.
-   **FlareSolverr**: A proxy server to bypass Cloudflare protection.

Each service can be enabled or disabled using the `arr_stack_<service_name>_enabled` variable. For example:

```yaml
arr_stack_radarr_enabled: true
arr_stack_sonarr_enabled: true
```

You can also customize the Docker image, version, and other settings for each service. See the `defaults/main.yml` file for a full list of variables.

## Usage

### Minimal Playbook

```yaml
- hosts: media-servers
  become: true
  roles:
    - role: install-docker
    - role: gluetun # Optional, if you use VPN routing
    - role: arr-stack
```