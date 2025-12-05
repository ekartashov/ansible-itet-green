#!/bin/bash
# NVIDIA GPU Power Monitoring Script (Dependency-Free Version)
# This script monitors power consumption using NVIDIA SMI
# It uses only bash builtins and standard Unix tools

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
  local current_ts=$(get_timestamp)

  # Calculate time components
  local seconds=$(( current_ts % 60 ))
  local minutes=$(( (current_ts % 3600) / 60 ))
  local hours=$(( (current_ts % 86400) / 3600 ))
  local day_of_month=$(( (current_ts / 86400) % 31 + 1 ))
  local month=$(( (current_ts / 2592000) % 12 + 1 ))
  local year=$(( (current_ts / 31536000) + 1970 ))

  # Format as ISO 8601
  printf "%04d-%02d-%02dT%02d:%02d:%02dZ" $year $month $day_of_month $hours $minutes $seconds
}

# Function to get hostname using /proc/self/cmdline
get_hostname() {
  # Read the command line arguments from /proc/self/cmdline
  local cmdline
  cmdline=$(<"/proc/self/cmdline")

  # The hostname is typically the first argument after the script name
  # Convert null-separated arguments to an array
  IFS=$'\0' read -r -a args <<< "$cmdline"

  # The hostname is typically the first argument
  echo "${args[0]}"
}

# Function to check if nvidia-smi is available
check_nvidia_smi() {
  if ! command -v nvidia-smi &> /dev/null; then
    local hostname=$(get_hostname)
    local timestamp=$(format_timestamp $(get_timestamp))
    echo "{\"timestamp\": \"$timestamp\", \"hostname\": \"$hostname\", \"error\": \"nvidia-smi_not_found\"}"
    exit 1
  fi
}

# Function to get GPU power data without external dependencies
get_gpu_power() {
  local hostname=$(get_hostname)

  # Use nvidia-smi to get power data, but process it with bash builtins
  local power_data
  power_data=$(nvidia-smi --query-gpu=timestamp,uuid,name,power.draw --format=csv,noheader,nounits)

  # Parse the CSV output using bash string manipulation
  IFS=',' read -r timestamp uuid name power_draw <<< "$power_data"

  # Remove leading whitespace from fields
  timestamp=${timestamp# }
  uuid=${uuid# }
  name=${name# }
  power_draw=${power_draw# }

  # Get current timestamp
  local current_ts=$(get_timestamp)
  local iso_timestamp=$(format_timestamp $current_ts)

  # Output JSON-like format using bash echo
  echo "{\"timestamp\": \"$iso_timestamp\", \"hostname\": \"$hostname\", \"gpu_uuid\": \"$uuid\", \"gpu_name\": \"$name\", \"power_draw_w\": $power_draw}"
}

# Main monitoring function
monitor_power() {
  local interval=$1

  # Check for nvidia-smi
  check_nvidia_smi

  # Monitor indefinitely
  while true; do
    # Get GPU power data
    local power_data
    power_data=$(get_gpu_power)

    # Output the data
    echo "$power_data"

    # Wait for the specified interval
    sleep "$interval"
  done
}

# Main script execution
if [ $# -ne 1 ]; then
  echo "Usage: $0 <interval_seconds>"
  exit 1
fi

interval=$1
monitor_power "$interval"