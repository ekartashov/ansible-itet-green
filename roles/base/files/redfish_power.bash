# usage:
# redfish_power.bash <BMC_IP> <USER> <PASSWORD>

#!/bin/bash

BMC_IP=$1
USER=$2
PASS=$3

if [[ -z "$BMC_IP" || -z "$USER" ]]; then
    echo "Usage: $0 <BMC_IP> <USER> <PASSWORD>"
    exit 1
fi

# 1. Dynamic Discovery: Get the Chassis URL
# We curl the Chassis collection and extract the first member's "@odata.id"
# We use -k (insecure) because BMC SSL certs are rarely signed.
CHASSIS_PATH=$(curl -s -k -u "$USER:$PASS" "https://$BMC_IP/redfish/v1/Chassis" | \
grep -o '"@odata.id": *"[^"]*"' | head -1 | awk -F'"' '{print $4}')

if [[ -z "$CHASSIS_PATH" ]]; then
    echo "{\"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"hostname\": \"$BMC_IP\", \"error\": \"chassis_not_found\"}"
    exit 1
fi

# 2. Get Power
# We append /Power to the discovered path
POWER_JSON=$(curl -s -k -u "$USER:$PASS" "https://$BMC_IP$CHASSIS_PATH/Power")

# 3. Extract Watts using grep/awk (No jq required)
# Looks for "PowerConsumedWatts": 123
WATTS=$(echo "$POWER_JSON" | grep -o '"PowerConsumedWatts": *[0-9.]*' | head -1 | awk -F': ' '{print $2}')

# Fallback: Some vendors use "AveragePowerWatts" if Consumed is null
if [[ -z "$WATTS" ]]; then
    WATTS=$(echo "$POWER_JSON" | grep -o '"AveragePowerWatts": *[0-9.]*' | head -1 | awk -F': ' '{print $2}')
fi

# 4. Handle Null/Empty readings
if [[ -z "$WATTS" ]]; then
    WATTS="null"
fi

# 5. Output JSON
printf "{\"timestamp\": \"%s\", \"bmc_ip\": \"%s\", \"metric\": \"total_system_power\", \"power_draw_w\": %s}\n" \
       "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$BMC_IP" "$WATTS"