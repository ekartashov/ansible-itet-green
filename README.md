# Ansible project for lostsecret-intel

## Layout

- `ansible.cfg`  
  Repo-local Ansible config (default inventory, roles path, etc.).

- `inventory/hosts.ini`  
  Ansible inventory.  
  Group: `lostsecret_intel`  
  Host: `lostsecret-intel` (this is the SSH **Host** from `~/.ssh/config`).

- `playbooks/site.yml`  
  Main entry playbook. Targets `lostsecret_intel` group and includes the `base` role.

- `roles/base/`  
  "Base" role. Put idempotent tasks that should **always** apply to this host
  (packages, services, users, etc.).

- `group_vars/lostsecret_intel.yml`  
  Variables shared across the `lostsecret_intel` group.

- `host_vars/lostsecret-intel.yml`  
  Variables specific to the single `lostsecret-intel` host (good place for
  per-host overrides).

- `scripts/run-ansible.sh`  
  Small wrapper script so you don't have to remember all CLI flags.

## Usage

Make sure your `~/.ssh/config` has something like:

\`\`\`
Host lostsecret-intel
  HostName <ip-or-dns-of-the-intel-box>
  User <your-user>
  # Port 22
  # IdentityFile ~/.ssh/some-key
\`\`\`

Then:

\`\`\bash
# From the project root:
./scripts/run-ansible.sh
\`\`\`

That runs `playbooks/site.yml` on the `lostsecret_intel` group (i.e. your
`lostsecret-intel` host) using your SSH config.

You can also pass options directly to `ansible-playbook`:

\`\`\bash
./scripts/run-ansible.sh playbooks/site.yml -vv      # more verbose
LIMIT=lostsecret_intel ./scripts/run-ansible.sh -vv  # override limit via env
\`\`\`
