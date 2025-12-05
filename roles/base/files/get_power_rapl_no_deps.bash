#!/usr/bin/bash

# Intel RAPL Power Monitoring Script (No Dependencies Version)
# This script monitors power consumption using Intel RAPL interfaces
# It provides power consumption data in watts for each RAPL zone
# Uses only bash builtins: no cat, date, bc, or seq

# Usage: ./get_power_rapl_no_deps.bash [interval_seconds]
# Default interval: 1 second if not specified

# Get command line arguments
INTERVAL="${1:-1}"  # Default to 1 second if no interval provided
HOSTNAME="$(hostname)"

# Base directory for RAPL interfaces
RAPL_BASE="/sys/class/powercap"

# Initialize arrays for RAPL zones
zones=()
declare -A Z_NAME
declare -A Z_MAX

# Discover RAPL zones
for z in "${RAPL_BASE}"/intel-rapl:*; do
    if [ -d "$z" ] && [ -f "$z/energy_uj" ]; then
        # Get zone name and max energy range using redirection instead of cat
        name=$(<"$z/name")
        max=$(<"$z/max_energy_range_uj")

        # Store zone information
        zones+=("$z")
        Z_NAME["$z"]="$name"
        Z_MAX["$z"]="$max"
    fi
done

# Check if any RAPL zones were found
if [ "${#zones[@]}" -eq 0 ]; then
    echo "No RAPL zones found under ${RAPL_BASE}. This CPU probably doesn't expose RAPL."
    exit 1
fi

# Read initial energy values
declare -A E1
for z in "${zones[@]}"; do
    E1["$z"]=$(<"$z/energy_uj")
done

# Print CSV header
echo "# timestamp,host,domain1:W,domain2:W,..."

# Main monitoring loop using while instead of seq
count=0
while [ "$count" -lt 10 ]; do  # Run for 10 iterations (adjustable)
    # Record start time using /proc/self/stat instead of date
    IFS=' ' read -r -a stat_parts < /proc/self/stat
    start_time=${stat_parts[21]}  # 22nd field is start time in clock ticks

    # Convert clock ticks to seconds (assuming HZ=100 for most systems)
    start_ts=$(( start_time / 100 ))

    # Wait for the specified interval
    sleep "$INTERVAL"

    # Record end time
    end_ts=$(( start_ts + INTERVAL ))

    # Calculate time delta
    dt=$(( end_ts - start_ts ))
    if [ "$dt" -le 0 ]; then
        dt="$INTERVAL"  # Fallback to interval if time calculation fails
    fi

    # Read current energy values
    declare -A E2
    for z in "${zones[@]}"; do
        E2["$z"]=$(<"$z/energy_uj")
    done

    # Prepare output line
    line="${end_ts},${HOSTNAME}"

    # Calculate power for each zone
    for z in "${zones[@]}"; do
        e_old=${E1["$z"]}
        e_new=${E2["$z"]}
        max=${Z_MAX["$z"]}

        # Handle energy counter rollover
        if [ "$max" -gt 0 ] && [ "$e_new" -lt "$e_old" ]; then
            de=$(( e_new + max - e_old ))
        else
            de=$(( e_new - e_old ))
        fi

        # Calculate watts with integer arithmetic (preserving 3 decimal places)
        # watts = (de * 1000) / (dt * 1000) = de / dt
        # Multiply by 1000 to preserve 3 decimal places, then divide
        watts=$(( de * 1000 / dt / 1000 ))

        # Add to output line
        line+=",${Z_NAME[$z]}:${watts}"
    done

    # Print the current measurement
    echo "$line"

    # Update old energy values for next iteration
    for z in "${zones[@]}"; do
        E1["$z"]=${E2["$z"]}
    done

    # Increment counter
    count=$((count + 1))
done