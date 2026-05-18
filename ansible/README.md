# Ansible

Ansible contains environment-specific inventories and reusable roles.

## Structure

- `inventories/dev`: development inventory and shared vars
- `playbooks/bootstrap.yml`: base server bootstrap
- `roles/common`: common baseline packages and configuration
- `roles/docker`: container runtime placeholder role
