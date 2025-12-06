#!/bin/bash
# Intel RAPL Power Monitoring Library
# Library for reading power consumption using Intel RAPL interfaces
# Designed to be sourced, not executed directly

# Function to read power data from Intel RAPL
# Sets local variables: POWER_DEVICE, POWER_VALUE, POWER_UNIT, POWER_TIMESTAMP
read_power_intel_rapl() {
    # Initialize output variables
    local POWER_DEVICE=""
    local POWER_VALUE=0
    local POWER_UNIT="W"
    local POWER_TIMESTAMP=$(date +%s)
    
    # Base directory for RAPL interfaces
    local RAPL_BASE="/sys/class/powercap"
    
    # Discover RAPL zones
    local zones=()
    local Z_NAME=()
    local Z_MAX=()
    
    # Find all RAPL zones
    for z in "${RAPL_BASE}"/intel-rapl:*; do
        if [[ -d "$z" && -f "$z/energy_uj" ]]; then
            # Get zone name and max energy range
            local name
            name=$(<"$z/name")
            local max
            max=$(<"$z/max_energy_range_uj")
            
            # Store zone information
            zones+=("$z")
            Z_NAME["$z"]="$name"
            Z_MAX["$z"]="$max"
        fi
    done
    
    # Check if any RAPL zones were found
    if [[ ${#zones[@]} -eq 0 ]]; then
        echo "No RAPL zones found under ${RAPL_BASE}. This CPU probably doesn't expose RAPL."
        return 1
    fi
    
    # Get initial energy values
    local E1=()
    for z in "${zones[@]}"; do
        E1["$z"]=$(<"$z/energy_uj")
    done
    
    # Wait a moment to get a measurement
    sleep 0.1
    
    # Get current energy values
    local E2=()
    for z in "${zones[@]}"; do
        E2["$z"]=$(<"$z/energy_uj")
    done
    
    # Calculate total power for all zones
    local total_power=0
    for z in "${zones[@]}"; do
        local e_old=${E1["$z"]}
        local e_new=${E2["$z"]}
        local max=${Z_MAX["$z"]}
        
        # Handle energy counter rollover
        local de
        if [[ "$max" -gt 0 && "$e_new" -lt "$e_old" ]]; then
            de=$(( e_new + max - e_old ))
        else
            de=$(( e_new - e_old ))
        fi
        
        # Calculate watts with integer arithmetic
        # watts = (de * 1000) / (dt * 1000) = de / dt
        # We use a time interval of 0.1 seconds
        local watts=$(( de * 1000 / 100 / 1000 ))
        total_power=$(( total_power + watts ))
    done
    
    # Set the output variables
    POWER_DEVICE="cpu_intel_rapl"
    POWER_VALUE=$total_power
    POWER_UNIT="W"
    POWER_TIMESTAMP=$(date +%s)
    
    # Export variables for use by caller
    export POWER_DEVICE POWER_VALUE POWER_UNIT POWER_TIMESTAMP
    
    return 0
}