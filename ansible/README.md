# Ansible

Ansible contains environment-specific inventories and reusable roles.

## Structure

- `inventories/dev`: development inventory and shared vars
- `playbooks/bootstrap.yml`: base server bootstrap
- `playbooks/site.yml`: app host runtime configuration
- `roles/common`: common baseline packages and configuration
- `roles/docker`: Docker Engine and Compose plugin installation
- `roles/cloudflared`: Cloudflare Tunnel container for reverse proxy ingress
- `roles/postgres`: RDS PostgreSQL client/extension setup

## Redis

Redis is **not** an Ansible role. The BE repo's `compose-{dev,prod}.yml` runs Redis
alongside the app on the same Docker network (the app connects by service name
`redis`, no host port exposed). The previous `roles/redis` (which started a separate
`moa-redis` container on `127.0.0.1:6379`) was an unused duplicate and was removed.

A later migration to ElastiCache remains easy: the BE app already reads
`REDIS_HOST`/`REDIS_PORT`, so only those env values would change.

## Cloudflare Tunnel

`cloudflared` is managed as a Docker Compose service on the app host.

Required runtime inputs:

- `cloudflared_tunnel_token`: Cloudflare Tunnel token. Inject via Ansible Vault, inventory secrets, environment variable, or `-e`; never commit the real value.
- `cloudflared_hostname`: Public hostname. Inject via `MOA_PUBLIC_HOSTNAME`, inventory, or `-e`; do not hardcode environment-specific domains in the role.

Run only this role:

```bash
export MOA_PUBLIC_HOSTNAME=...
export CLOUDFLARED_TUNNEL_TOKEN=...
ansible-playbook ansible/playbooks/site.yml --tags cloudflared
```

Cloudflare DNS/ingress is expected to point the configured public hostname at the Cloudflare Tunnel and then reverse proxy to the EC2 origin.
