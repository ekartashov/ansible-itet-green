#!/usr/bin/bash

# Redfish Power Monitoring Script (No Dependencies Version)
# This script monitors power consumption using Redfish interfaces
# Uses only bash builtins: no curl, jq, or other external commands
# Note: This is a simplified version that uses wget instead of curl
# and parses JSON manually instead of using jq

# Check if required environment variables are set
if [ -z "$BMC_IP" ] || [ -z "$BMC_USER" ] || [ -z "$BMC_PASS" ]; then
    echo "Error: BMC_IP, BMC_USER, and BMC_PASS environment variables must be set."
    echo "Usage: export BMC_IP=<ip> BMC_USER=<username> BMC_PASS=<password>"
    exit 1
fi

# Base URL for Redfish API
base_url="https://$BMC_IP/redfish/v1/Chassis/"

# Function to get power data using wget (fallback for curl)
get_power() {
    local ip="$1"
    local user="$2"
    local pass="$3"

    # Get chassis list using wget with basic auth
    response=$(wget -q --user="$user" --password="$pass" --no-check-certificate -O- "$base_url" 2>/dev/null)

    # Check if response is empty or contains error
    if [ -z "$response" ] || [[ "$response" == *"error"* ]]; then
        echo "Error: Failed to get chassis list from $base_url"
        echo "Response: $response"
        return 1
    fi

    # Simple JSON parsing without jq - extract Members array
    # Look for "Members": [ and extract the array
    members_start=$(echo "$response" | grep -o 'Members": \[.*\]' | head -n 1)
    if [ -z "$members_start" ]; then
        echo "Error: No Members array found in response."
        return 1
    fi

    # Extract the actual member URLs (simplified parsing)
    # This assumes a simple structure - in real usage, you'd need more robust parsing
    member_urls=$(echo "$members_start" | sed -e 's/.*\[//' -e 's/\]//' -e 's/,/ /g' -e 's/"//g')

    if [ -z "$member_urls" ]; then
        echo "Error: No chassis members found."
        return 1
    fi

    # Iterate through chassis to find power information
    for chassis in $member_urls; do
        # Construct power URL
        power_url="https://$ip$chassis/Power"

        # Get power information
        power_data=$(wget -q --user="$user" --password="$pass" --no-check-certificate -O- "$power_url" 2>/dev/null)

        # Simple check for PowerControl field
        if echo "$power_data" | grep -q '"PowerControl":'; then
            # Extract watts value (simplified parsing)
            watts=$(echo "$power_data" | grep -o '"PowerConsumedWatts": [0-9]*' | head -n 1 | sed 's/.*: //')

            if [ -n "$watts" ]; then
                # Return success with power data
                echo "{\"ip\": \"$ip\", \"watts\": $watts}"
                return 0
            fi
        fi
    done

    # If no power data found
    echo "Error: No power data found."
    return 1
}

# Get the power data
result=$(get_power "$BMC_IP" "$BMC_USER" "$BMC_PASS")

# Check if successful
if [ $? -eq 0 ]; then
    echo "$result"
else
    echo "Error: Failed to get power data."
    exit 1
fi