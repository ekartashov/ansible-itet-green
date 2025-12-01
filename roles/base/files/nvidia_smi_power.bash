#!/bin/bash

# 1. Check for nvidia-smi
if ! command -v nvidia-smi &> /dev/null; then
    echo "{\"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"hostname\": \"$(hostname)\", \"error\": \"nvidia-smi_not_found\"}"
    exit 1
fi

# 2. Infinite Loop
while true; do
    # Query GPU data as CSV, then pipe to awk to format as JSON
    nvidia-smi --query-gpu=timestamp,uuid,name,power.draw \
               --format=csv,noheader,nounits | \
    awk -F, -v host="$(hostname)" '
    {
        # Trim leading whitespace from fields caused by csv format
        gsub(/^ /, "", $2); gsub(/^ /, "", $3); gsub(/^ /, "", $4);
        
        # Print JSON structure
        printf "{\"timestamp\": \"%s\", \"hostname\": \"%s\", \"gpu_uuid\": \"%s\", \"gpu_name\": \"%s\", \"power_draw_w\": %s}\n", $1, host, $2, $3, $4
    }'
    
    sleep 1
done