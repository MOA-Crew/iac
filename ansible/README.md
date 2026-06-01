# Ansible

Ansible contains environment-specific inventories and reusable roles.

## Structure

- `inventories/dev`: development inventory and shared vars
- `playbooks/bootstrap.yml`: base server bootstrap
- `playbooks/site.yml`: app host runtime configuration
- `roles/common`: common baseline packages and configuration
- `roles/docker`: Docker Engine and Compose plugin installation
- `roles/redis`: Redis Docker Compose service for dev cache/session/verification use
- `roles/postgres`: RDS PostgreSQL client/extension setup

## Redis dev runtime

Redis is installed on the app EC2 through Docker Compose instead of ElastiCache for the current dev stage.

Why: the BE app already reads `REDIS_HOST`/`REDIS_PORT`, and a localhost-only Redis keeps dev infra cheaper and simpler while preserving an easy later migration path to ElastiCache.

Default shape:

```text
BE on app EC2 -> 127.0.0.1:6379 -> Redis container
```

The role renders `/opt/moa/redis/compose.yml` and starts it with `docker compose up -d`.

Security default:

- Redis binds to `127.0.0.1:6379` only.
- No Redis password is required for localhost-only dev use.
- The role refuses `0.0.0.0` binding unless `redis_password` is set.

Run only Redis:

```bash
ansible-playbook ansible/playbooks/site.yml --tags redis
```

Override examples:

```bash
ansible-playbook ansible/playbooks/site.yml \
  --tags redis \
  -e "redis_bind_address=127.0.0.1 redis_port=6379"
```

If Redis must be accessed from another host later, prefer ElastiCache. If temporarily exposing Redis beyond localhost, restrict the EC2 security group and set `redis_password`.
