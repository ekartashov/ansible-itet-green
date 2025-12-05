#!/bin/bash
# AMD RAPL Power Monitoring Script (Dependency-Free Version)
# This script monitors power consumption using AMD RAPL interface
# It uses only bash builtins and standard Unix tools

# Function to read energy counter from RAPL interface
read_energy_counter() {
  local counter_file=$1
  local energy_counter=0

  # Read the energy counter value
  if [[ -f "$counter_file" ]]; then
    # Use redirection instead of cat
    energy_counter=$(<"$counter_file")
  fi

  echo "$energy_counter"
}

# Function to get timestamp
get_timestamp() {
  # Use /proc/self/stat for process start time
  IFS=' ' read -r -a stat_parts < /proc/self/stat
  local start_time=${stat_parts[21]}  # 22nd field is start time in clock ticks

  # Convert clock ticks to seconds (assuming HZ=100 for most systems)
  local start_ts=$(( start_time / 100 ))

  echo "$start_ts"
}

# Function to calculate power in watts
calculate_power() {
  local energy_diff=$1
  local time_diff=$2

  # Calculate watts with integer arithmetic
  # watts = (energy_diff * 1000) / (time_diff * 1000) = energy_diff / time_diff
  local watts=$(( energy_diff * 1000 / time_diff / 1000 ))

  echo "$watts"
}

# Main monitoring function
monitor_power() {
  local interval=$1
  local rapl_path="/sys/class/powercap/intel-rapl"

  # Find AMD RAPL devices
  local amd_rapl_devices=()
  for z in "$rapl_path"/intel-rapl:*:; do
    if [[ -d "$z" ]]; then
      amd_rapl_devices+=("$z")
    fi
  done

  if [ ${#amd_rapl_devices[@]} -eq 0 ]; then
    echo "No AMD RAPL devices found"
    return 1
  fi

  # Initialize variables
  local start_ts=$(get_timestamp)
  local start_energy=0
  local end_energy=0
  local end_ts=0
  local total_power=0

  # Read initial energy counter
  for z in "${amd_rapl_devices[@]}"; do
    start_energy=$(( start_energy + $(read_energy_counter "$z/energy_uj") ))
  done

  # Monitor for the specified interval
  sleep "$interval"

  # Get end timestamp
  end_ts=$(get_timestamp)

  # Read final energy counter
  for z in "${amd_rapl_devices[@]}"; do
    end_energy=$(( end_energy + $(read_energy_counter "$z/energy_uj") ))
  done

  # Calculate time difference
  local time_diff=$(( end_ts - start_ts ))

  # Calculate power
  local energy_diff=$(( end_energy - start_energy ))
  local power=$(calculate_power "$energy_diff" "$time_diff")

  # Output results
  echo "AMD RAPL Power Monitoring Results:"
  echo "-----------------------------------"
  echo "Start Time: $(date -d @$start_ts)"
  echo "End Time: $(date -d @$end_ts)"
  echo "Time Interval: $time_diff seconds"
  echo "Energy Consumed: $energy_diff microjoules"
  echo "Power Consumption: $power watts"
  echo "-----------------------------------"
}

# Main script execution
if [ $# -ne 1 ]; then
  echo "Usage: $0 <interval_seconds>"
  exit 1
fi

interval=$1
monitor_power "$interval"