#!/usr/bin/env bash
set -euo pipefail

# Default playbook
PLAYBOOK="${1:-playbooks/site.yml}"

# Allow overriding limit via env, but default to this project host group
LIMIT="${LIMIT:-lostsecret_intel}"

# Set sudo password for testing purposes
export ANSIBLE_BECOME_PASS="user1234"

# Shift playbook argument if provided, so remaining args go to ansible-playbook
shift || true

ansible-playbook --verbose "$PLAYBOOK" --limit "$LIMIT" "$@"
