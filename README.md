![homelav-v2.drawio.png](homelav-v1.drawio.png)

# Homelab

This repository contains the infrastructure as code (IaC) to deploy and manage a personal homelab. It uses Terraform to provision virtual machines on Proxmox and Ansible to configure the services and applications.

## Repository Structure

```
.
├── ansible/
│   ├── roles/
│   │   ├── arr-stack/
│   │   ├── base-storage/
│   │   ├── gluetun/
│   │   ├── homepage/
│   │   ├── install-docker/
│   │   └── monitoring/
│   ├── inventory/
│   ├── playbooks/
│   └── ...
├── proxmox/
│   └── README-Proxmox.md
└── terraform/
    ├── environments/
    │   ├── prod/
    │   └── test/
    └── modules/
        └── proxmox-vm-ubuntu-24-cloudinit/
```

-   `ansible/`: Contains Ansible playbooks and roles for configuration management.
    -   `roles/`: Each role is responsible for a specific service (e.g., `arr-stack`, `monitoring`). See the README in each role's directory for more details.
-   `terraform/`: Contains Terraform configurations for infrastructure provisioning.
    -   `modules/`: Reusable Terraform modules (e.g., for creating a Proxmox VM).
    -   `environments/`: Environment-specific configurations (e.g., `prod`, `test`).
-   `proxmox/`: Documentation related to Proxmox setup and VM templates.

## Getting Started

This guide will help you to deploy the entire homelab infrastructure and services from scratch.

### 1. Prerequisites

-   A Proxmox server up and running.
-   A Cloud-Init template configured on Proxmox. See the [Proxmox README](./proxmox/README-Proxmox.md) for instructions.

### 2. Infrastructure Deployment

Use Terraform to create the virtual machines, networks, and storage. See the [Terraform README](./terraform/README.md) for detailed instructions on how to set up the provider and deploy the infrastructure.

### 3. Configuration Management

Use Ansible to configure the services and applications on the provisioned VMs. See the [Ansible README](./ansible/README.md) for instructions on how to run the playbooks.

## Services

The following services are managed by this repository:

-   **Arr stack**: Radarr, Sonarr, Prowlarr, qBittorrent, Jellyseerr, Jellyfin, and FlareSolverr.
-   **Monitoring**: Prometheus, Grafana, and cAdvisor.
-   **Homepage**: A simple and clean homepage to access all your services.
-   **Gluetun**: A VPN client container to route traffic through a VPN.

For more details on each service, see the corresponding Ansible role's README.

### ARR Stack Configuration

- Configure arr applications through UI (The configuration as code is not yet implemented)
    - Go to homelab page: `http://<bastion-server-ip>:3000`
    - From there you have access to all the applications (Jellyfin, Radarr, Sonarr, etc)
    - Configure each application (Jellyfin, Radarr, Sonarr, etc), here is some useful links to help you with the initial configuration:
        - [arr stack](https://yams.media/config/)