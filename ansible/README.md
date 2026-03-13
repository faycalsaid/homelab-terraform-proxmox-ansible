# Ansible

This directory contains Ansible playbooks and roles to configure the homelab services and applications.

## Directory Structure

-   `inventory/`: Contains the inventory files, group variables, and host variables.
-   `playbooks/`: Contains the main playbooks to be executed.
-   `roles/`: Contains the roles that are used by the playbooks.
-   `requirements.yml`: Contains the required Ansible collections.

## Developer Guide

### Prerequisites

Install `ansible-core` and the required collections:

```bash
pip install --upgrade ansible-core
ansible-galaxy collection install -r requirements.yml
```

### Running Playbooks

To run the main playbook that configures all the services, use the following command:

```bash
ansible-playbook ./playbooks/k3s.yml
```

To run a specific playbook, for example `docker.yml`:

```bash
ansible-playbook ./playbooks/docker.yml
```

To deploy OpenClaw (dedicated AI VM):

```bash
ansible-playbook ./playbooks/openclaw.yml
```

### Managing Secrets with Vault

To encrypt secrets, use `ansible-vault`. For example, to encrypt a string:

```bash
ansible-vault encrypt_string --ask-vault-pass "your-secret-string" --name "your_property_name"
```

## Special Notes

### Jinja Evaluation in Inventory Files

Although this repository follows standard Ansible conventions for `group_vars` and `host_vars`, YAML files in those directories are not Jinja-evaluated by default.

To enable variable interpolation (e.g., referencing one variable from another) inside inventory variable files, a small pre-task is added in the playbooks to explicitly load and render them as templates. This ensures that all variables are properly evaluated and reusable throughout the playbook and roles.

```yaml
pre_tasks:
  - name: Load evaluated group vars (to resolve Jinja expressions)
    include_vars:
      file: "/group_vars/media-servers.yml"
```