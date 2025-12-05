#!/usr/bin/bash

# System Information Gathering Script
# This script collects system hardware information
# Uses only bash builtins with minimal dependencies

# Get basic system information
echo "System Information:"
echo "==================="
echo "Hostname: $(hostname)"
echo "Operating System: $(uname -a)"
echo "Kernel Version: $(uname -r)"
echo "Architecture: $(uname -m)"
echo

# Get CPU information
echo "CPU Information:"
echo "================="
cpu_model=$(grep 'model name' /proc/cpuinfo | head -n 1 | cut -d ':' -f 2 | sed 's/^ //')
echo "Model: $cpu_model"
cpu_cores=$(grep -c 'processor' /proc/cpuinfo)
echo "Cores: $cpu_cores"
echo

# Get Memory information
echo "Memory Information:"
echo "===================="
total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_mem_mb=$(( total_mem_kb / 1024 ))
echo "Total: ${total_mem_mb} MB"
free_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
free_mem_mb=$(( free_mem_kb / 1024 ))
echo "Available: ${free_mem_mb} MB"
echo

# Get Disk information
echo "Disk Information:"
echo "==================="
df_output=$(df -h /)
echo "$df_output"
echo

# Get Network information
echo "Network Information:"
echo "====================="
ip_output=$(ip -4 addr show | grep 'inet ' | head -n 1 | awk '{print $2}' | cut -d '/' -f 1)
echo "IP Address: $ip_output"
echo

# Get GPU information (if available)
if [ -f /usr/bin/lspci ]; then
    echo "GPU Information:"
    echo "================="
    lspci_output=$(lspci | grep -i vga)
    if [ -n "$lspci_output" ]; then
        echo "$lspci_output"
    else
        echo "No GPU detected"
    fi
    echo
else
    echo "GPU Information:"
    echo "================="
    echo "lspci not available - cannot detect GPU"
    echo
fi

# Get RAPL support information
echo "RAPL Support Information:"
echo "========================="
if [ -d /sys/class/powercap ]; then
    echo "RAPL interface available at /sys/class/powercap"
    rapl_zones=$(find /sys/class/powercap -name "intel-rapl*" -type d)
    if [ -n "$rapl_zones" ]; then
        echo "Intel RAPL zones found:"
        for zone in $rapl_zones; do
            zone_name=$(<"$zone/name")
            echo "  - $zone_name"
        done
    else
        echo "No Intel RAPL zones found"
    fi
else
    echo "RAPL interface not available"
fi
echo

echo "Script completed successfully"