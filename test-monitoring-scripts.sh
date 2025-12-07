#!/bin/bash
# Comprehensive test for power monitoring scripts
# This script validates that all monitoring scripts follow the required output contract

echo "=== POWER MONITORING SCRIPTS VALIDATION ==="
echo

# Test directory - adjust this if your scripts are elsewhere
SCRIPT_DIR="/usr/local/share/zabbix_power_monitoring"

# Check if directory exists
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "ERROR: Script directory $SCRIPT_DIR does not exist"
    echo "This suggests deployment didn't occur properly"
    exit 1
fi

echo "Testing all monitoring scripts in $SCRIPT_DIR"
echo "==========================================="

# Function to test a script
test_script() {
    local script_name=$1
    local script_path="$SCRIPT_DIR/$script_name"
    
    if [ ! -f "$script_path" ]; then
        echo "❌ $script_name - MISSING"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        echo "❌ $script_name - NOT EXECUTABLE"
        return 1
    fi
    
    echo -n "Testing $script_name: "
    
    # Execute the script and capture output and exit code
    OUTPUT=$($script_path 2>&1)
    EXIT_CODE=$?
    
    # Validate output contract
    if [ $EXIT_CODE -eq 0 ]; then
        # Success case - should output exactly one numeric value
        if [[ "$OUTPUT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo "✅ PASS - Output: $OUTPUT (Exit code: $EXIT_CODE)"
            return 0
        else
            echo "❌ FAIL - Invalid output format: '$OUTPUT' (Exit code: $EXIT_CODE)"
            return 1
        fi
    else
        # Failure case - should output nothing and exit non-zero
        if [ -z "$OUTPUT" ]; then
            echo "✅ PASS - No output with non-zero exit code ($EXIT_CODE)"
            return 0
        else
            echo "❌ FAIL - Unexpected output: '$OUTPUT' with exit code $EXIT_CODE"
            return 1
        fi
    fi
}

# Test all the scripts
echo "Testing CPU RAPL script:"
test_script "read_cpu_rapl_power.sh"

echo
echo "Testing RAM RAPL script:"
test_script "read_ram_rapl_power.sh"

echo
echo "Testing GPU NVIDIA script:"
test_script "read_gpu_nvidia_power.sh"

echo
echo "Testing GPU AMD script:"
test_script "read_gpu_amd_power.sh"

echo
echo "Testing Redfish script:"
test_script "read_redfish_power.sh"

echo
echo "Testing GPU discovery script:"
test_script "discover_gpu_sensors.sh"

echo
echo "=== VALIDATION COMPLETE ==="
echo "If all tests show ✅ PASS, scripts follow Zabbix output contract correctly."

# Additional validation: check file permissions and content
echo
echo "=== FILE VALIDATION ==="
for file in "$SCRIPT_DIR"/*.sh; do
    if [ -f "$file" ]; then
        echo "$(basename "$file") - $(stat -c "%A %n" "$file")"
    fi
done