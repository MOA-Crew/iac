# SW-Hub IaC

Infrastructure bootstrap repository for the SW-Hub project.

This repository separates provisioning and configuration management in one mono-repo:

- **Terraform**: cloud/network/compute provisioning skeleton
- **Ansible**: host bootstrap and configuration management skeleton

## Repository layout

```text
.
├── ansible/
│   ├── inventories/
│   │   └── dev/
│   ├── playbooks/
│   └── roles/
├── docs/
└── terraform/
    ├── environments/
    │   └── dev/
    └── modules/
        ├── compute/
        └── network/
```

## Design intent

- Keep **Terraform** responsible for infra provisioning boundaries.
- Keep **Ansible** responsible for OS/bootstrap/runtime configuration.
- Start with a **dev** environment first, then extend to staging/prod.
- Avoid hardcoding secrets; use environment variables or a secret manager later.

## Quick start

### Terraform

```bash
cd terraform/environments/dev
terraform init
terraform validate
terraform plan
```

### Ansible

```bash
cd ansible
ansible-inventory -i inventories/dev/hosts.yml --graph
ansible-playbook -i inventories/dev/hosts.yml playbooks/bootstrap.yml --check
```

## Next steps

1. Replace placeholder CIDRs, hostnames, and IPs.
2. Wire real cloud provider resources into the Terraform modules.
3. Expand Ansible roles for Docker, reverse proxy, app runtime, and observability.
4. Add CI for formatting and validation.
