#!/usr/bin/bash

# Standardized Error Handling Functions for Power Monitoring Scripts
# This file provides common error handling functions that can be sourced
# by other monitoring scripts to ensure consistent error handling behavior

# Function to check if a command exists
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' not found." >&2
        exit 1
    fi
}

# Function to handle file reading errors
read_file_safely() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "Error: File '$file' not found or not accessible." >&2
        return 1
    fi
    cat "$file" 2>/dev/null
    return $?
}

# Function to handle directory listing errors
list_directory_safely() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' not found or not accessible." >&2
        return 1
    fi
    ls -1 "$dir" 2>/dev/null
    return $?
}

# Function to handle JSON parsing errors (requires jq)
parse_json_safely() {
    local json="$1"
    if [ -z "$json" ]; then
        echo "Error: Empty JSON input." >&2
        return 1
    fi
    echo "$json" | jq . > /dev/null 2>&1
    return $?
}

# Function to handle network/curl errors
curl_safely() {
    local url="$1"
    local timeout="${2:-10}"

    # Use curl with error handling
    local result
    result=$(curl -s -w "%{http_code}" -o /dev/stdout -k "$url" 2>/dev/null)

    # Check if curl succeeded
    if [ $? -ne 0 ]; then
        echo "Error: curl failed to connect to $url" >&2
        return 1
    fi

    # Check HTTP status code
    local status_code
    status_code=$(echo "$result" | tail -n1)

    if [ "$status_code" -ge 400 ]; then
        echo "Error: HTTP error $status_code when accessing $url" >&2
        return 1
    fi

    # Return the actual content (without the status code)
    echo "$result" | sed '$d'
    return 0
}

# Function to handle process timing (alternative to date)
get_timestamp() {
    # Read process start time from /proc/self/stat
    IFS=' ' read -r -a stat_parts < /proc/self/stat
    local start_time=${stat_parts[21]}  # 22nd field is start time in clock ticks

    # Convert clock ticks to seconds (assuming HZ=100 for most systems)
    echo $(( start_time / 100 ))
}

# Function to handle integer arithmetic with scaling (alternative to bc)
calculate_watts() {
    local de="$1"
    local dt="$2"

    # Calculate watts with integer arithmetic (preserving 3 decimal places)
    # watts = (de * 1000) / (dt * 1000) = de / dt
    # Multiply by 1000 to preserve 3 decimal places, then divide
    local watts=$(( de * 1000 / dt / 1000 ))

    echo "$watts"
}

# Function to handle energy counter rollover
handle_energy_rollover() {
    local e_old="$1"
    local e_new="$2"
    local max="$3"

    # Handle energy counter rollover
    if [ "$max" -gt 0 ] && [ "$e_new" -lt "$e_old" ]; then
        echo $(( e_new + max - e_old ))
    else
        echo $(( e_new - e_old ))
    fi
}

# Function to print JSON error message
print_json_error() {
    local error_msg="$1"
    echo "{\"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"hostname\": \"$(hostname)\", \"error\": \"$error_msg\"}"
    exit 1
}

# Function to validate required environment variables
validate_env_vars() {
    local required_vars="$@"
    for var in $required_vars; do
        if [ -z "${!var}" ]; then
            echo "Error: Required environment variable '$var' is not set." >&2
            return 1
        fi
    done
    return 0
}

# Function to handle missing RAPL zones
handle_missing_rapl_zones() {
    local base_dir="$1"
    local zones=()
    declare -A Z_NAME
    declare -A Z_MAX

    for z in "${base_dir}"/intel-rapl:*; do
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
        echo "No RAPL zones found under ${base_dir}. This CPU probably doesn't expose RAPL."
        return 1
    fi

    echo "ZONES_FOUND"
    return 0
}

# Export functions for sourcing
export -f check_command
export -f read_file_safely
export -f list_directory_safely
export -f parse_json_safely
export -f curl_safely
export -f get_timestamp
export -f calculate_watts
export -f handle_energy_rollover
export -f print_json_error
export -f validate_env_vars
export -f handle_missing_rapl_zones