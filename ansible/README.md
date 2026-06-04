# Ansible

Ansible contains environment-specific inventories and reusable roles.

## Structure

- `inventories/dev`: development inventory and shared vars
- `playbooks/bootstrap.yml`: base server bootstrap
- `roles/common`: common baseline packages and configuration
- `roles/docker`: container runtime placeholder role

- `roles/cloudflared`: Cloudflare Tunnel container for reverse proxy ingress

## Cloudflare Tunnel

`cloudflared` is managed as a Docker Compose service on the app host.

Required runtime secret:

- `cloudflared_tunnel_token`: Cloudflare Tunnel token. Inject via Ansible Vault, inventory secrets, or `-e`; never commit the real value.

Run only this role:

```bash
ansible-playbook playbooks/site.yml --tags cloudflared -e "cloudflared_tunnel_token=..."
```

Cloudflare DNS/ingress is expected to point public hostnames, such as temporary `*.yeoun.org` records, at the Cloudflare Tunnel and then reverse proxy to the EC2 origin.
