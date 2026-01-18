terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://192.168.1.151:8006/api2/json"
  pm_tls_insecure = true

  pm_parallel     = 1
  pm_timeout      = 600
}
