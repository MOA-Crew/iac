# SW-Hub Infrastructure Draft

This is a shallow first-pass scaffold based on the current infra planning direction.

## Initial shape

- **Terraform** owns:
  - network boundaries
  - security group / firewall boundaries
  - compute group definitions
- **Ansible** owns:
  - base package bootstrap
  - common server configuration
  - container runtime preparation

## Suggested rollout order

1. Stand up the dev network and compute skeleton with Terraform.
2. Bootstrap access, base packages, and runtime prerequisites with Ansible.
3. Add service-specific roles only after the base topology is stable.

## Conventions

- `terraform/environments/*` = deployable entrypoints
- `terraform/modules/*` = reusable infra building blocks
- `ansible/inventories/*` = environment-specific inventory
- `ansible/roles/*` = reusable configuration roles
