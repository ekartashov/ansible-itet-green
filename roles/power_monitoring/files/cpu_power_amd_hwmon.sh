#!/usr/bin/env bash
# CPU power via AMD hwmon (fam15h_power / zenpower)
# Strictly runtime-only: detection is done in Ansible.
# Outputs watts as a single float with 3 decimals, e.g.: 42.123

set -euo pipefail

CONFIG_FILE="/etc/power-monitoring/amd_hwmon.conf"

# Load AMD_HWMON_DIR from config if present
if [ -r "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi

# Expect Ansible to have written AMD_HWMON_DIR
if [ "${AMD_HWMON_DIR:-}" = "" ] || [ ! -d "$AMD_HWMON_DIR" ]; then
  # Consistent failure output for monitoring systems
  printf '0.000\n'
  exit 1
fi

total_uW=0

# Sum all power*_input values (in microwatts)
for f in "$AMD_HWMON_DIR"/power*_input; do
  [ -r "$f" ] || continue
  IFS= read -r value < "$f" || value=''

  # Ensure it's an integer
  case "$value" in
    ''|*[!0-9]*)
      continue
      ;;
  esac

  total_uW=$(( total_uW + value ))
done

if [ "$total_uW" -le 0 ]; then
  printf '0.000\n'
  exit 1
fi

# Convert µW -> W with 3 decimals:
#   W = total_uW / 1_000_000
#   milli = (total_uW % 1_000_000) / 1_000
watts=$(( total_uW / 1000000 ))
micro=$(( total_uW % 1000000 ))
milli=$(( micro / 1000 ))

# Print as X.YYY
printf '%d.%03d\n' "$watts" "$milli"
