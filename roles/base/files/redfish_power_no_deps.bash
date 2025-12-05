#!/bin/bash
# Redfish Power Monitoring Script (Parsing with Pure Bash Builtins)
# Dependencies: bash builtins + wget only

# ---------------------------
# Timestamp helpers (unchanged logic)
# ---------------------------

# Function to get timestamp using /proc/self/stat
get_timestamp() {
  IFS=' ' read -r -a stat_parts < /proc/self/stat
  local start_time=${stat_parts[21]}  # 22nd field is start time in clock ticks

  # Convert clock ticks to seconds (assuming HZ=100 for most systems)
  local start_ts=$(( start_time / 100 ))

  echo "$start_ts"
}

# Function to format timestamp in ISO 8601 format
format_timestamp() {
  local timestamp=$1

  # Get current time components using /proc/self/stat
  local current_ts
  current_ts=$(get_timestamp)

  # Calculate time components
  local seconds=$(( current_ts % 60 ))
  local minutes=$(( (current_ts % 3600) / 60 ))
  local hours=$(( (current_ts % 86400) / 3600 ))
  local day_of_month=$(( (current_ts / 86400) % 31 + 1 ))
  local month=$(( (current_ts / 2592000) % 12 + 1 ))
  local year=$(( (current_ts / 31536000) + 1970 ))

  # Format as ISO 8601
  printf "%04d-%02d-%02dT%02d:%02d:%02dZ" \
    "$year" "$month" "$day_of_month" "$hours" "$minutes" "$seconds"
}

# Function to get hostname "fallback" (kept as-is)
# NOTE: This does NOT actually return the system hostname;
# it's returning argv[0]. Kept to avoid scope creep.
get_hostname() {
  local cmdline
  cmdline=$(<"/proc/self/cmdline")
  IFS=$'\0' read -r -a args <<< "$cmdline"
  echo "${args[0]}"
}

# ---------------------------
# Wget availability check
# ---------------------------

check_wget() {
  if ! command -v wget &> /dev/null; then
    local hostname timestamp
    hostname=$(get_hostname)
    timestamp=$(format_timestamp "$(get_timestamp)")
    echo "{\"timestamp\": \"$timestamp\", \"hostname\": \"$hostname\", \"error\": \"wget_not_found\"}"
    exit 1
  fi
}

# ---------------------------
# Pure-bash JSON helpers
# ---------------------------

# Remove simple whitespace characters from JSON for easier matching.
# This is intentionally naive but sufficient for numeric/path fields.
json_compact() {
  local s=$1
  s=${s//$'\n'/}
  s=${s//$'\r'/}
  s=${s//$'\t'/}
  s=${s// /}
  printf '%s' "$s"
}

# Extract an unquoted token (number/null/bool) until a JSON delimiter.
# Builtins only.
extract_token_until_delim() {
  local s=$1 out="" i ch
  for (( i=0; i<${#s}; i++ )); do
    ch=${s:i:1}
    case "$ch" in
      ','|'}'|']') break ;;
    esac
    out+="$ch"
  done
  printf '%s' "$out"
}

# Extract first occurrence of a JSON key's value.
# Handles either:
#   "key":"string"
#   "key":123
#   "key":null
# Returns empty if key not found or value is null.
extract_json_value() {
  local json=$1 key=$2
  local s part val

  s=$(json_compact "$json")

  # Find the key
  part=${s#*\"$key\"}
  [[ "$part" == "$s" ]] && return 1

  # Skip ':' after key
  part=${part#*:}

  # Quoted string?
  if [[ "$part" == \"* ]]; then
    part=${part#\"}
    val=${part%%\"*}
    printf '%s' "$val"
    return 0
  fi

  # Unquoted token
  val=$(extract_token_until_delim "$part")

  # Treat null as empty
  [[ "$val" == "null" ]] && return 1

  printf '%s' "$val"
}

# Redfish Chassis index usually looks like:
#  { ..., "Members":[ {"@odata.id":"/redfish/v1/Chassis/XYZ"}, ... ] }
# This tries to locate Members first, then first @odata.id inside it.
extract_first_chassis_member_id() {
  local json=$1
  local s part val

  s=$(json_compact "$json")

  # Narrow down to Members array
  part=${s#*\"Members\":[}
  [[ "$part" == "$s" ]] && return 1

  # Find first @odata.id after Members:[
  part=${part#*\"@odata.id\"}
  [[ "$part" == "$s" ]] && return 1

  part=${part#*:}

  # Expecting a quoted string
  [[ "$part" != \"* ]] && return 1
  part=${part#\"}
  val=${part%%\"*}

  printf '%s' "$val"
}

# ---------------------------
# HTTP helper
# ---------------------------

# Wrapper around wget to keep options consistent.
# REDFISH_INSECURE=1 (default) allows self-signed BMC certs.
wget_json() {
  local url=$1 user=$2 pass=$3
  local -a args

  args=(-qO-)

  if [[ "${REDFISH_INSECURE:-1}" == "1" ]]; then
    args+=(--no-check-certificate)
  fi

  # Basic auth
  args+=(--user="$user" --password="$pass")

  wget "${args[@]}" "$url" 2>/dev/null
}

# ---------------------------
# Main power collection
# ---------------------------

get_power() {
  local bmc_ip=$1 user=$2 pass=$3

  # Get Chassis index JSON
  local chassis_index_json
  chassis_index_json=$(wget_json "https://$bmc_ip/redfish/v1/Chassis" "$user" "$pass")

  # Extract first member chassis path
  local chassis_path
  chassis_path=$(extract_first_chassis_member_id "$chassis_index_json") || chassis_path=""

  if [[ -z "$chassis_path" ]]; then
    local hostname timestamp
    hostname=$(get_hostname)
    timestamp=$(format_timestamp "$(get_timestamp)")
    echo "{\"timestamp\": \"$timestamp\", \"hostname\": \"$bmc_ip\", \"error\": \"chassis_not_found\"}"
    return 1
  fi

  # Get Power JSON
  local power_json
  power_json=$(wget_json "https://$bmc_ip$chassis_path/Power" "$user" "$pass")

  # Extract Watts
  local watts
  watts=$(extract_json_value "$power_json" "PowerConsumedWatts") || watts=""

  # Fallback
  if [[ -z "$watts" ]]; then
    watts=$(extract_json_value "$power_json" "AveragePowerWatts") || watts=""
  fi

  # Handle null/empty readings
  if [[ -z "$watts" ]]; then
    watts="null"
  fi

  local timestamp
  timestamp=$(format_timestamp "$(get_timestamp)")

  echo "{\"timestamp\": \"$timestamp\", \"bmc_ip\": \"$bmc_ip\", \"metric\": \"total_system_power\", \"power_draw_w\": $watts}"
}

# ---------------------------
# Entrypoint
# ---------------------------

if [ $# -ne 3 ]; then
  echo "Usage: $0 <BMC_IP> <USER> <PASSWORD>"
  exit 1
fi

bmc_ip=$1
user=$2
pass=$3

check_wget
get_power "$bmc_ip" "$user" "$pass"