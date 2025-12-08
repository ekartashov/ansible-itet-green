# Ansible-Based Power Monitoring

A host-side, Ansible-driven power monitoring framework that integrates with Zabbix via UserParameters. Designed for heterogeneous, university-style hardware with minimal dependencies and conservative system changes.

## Project Overview

This project implements a minimal-dependency, host-local power monitoring framework that:
- Detects available power interfaces at deployment time
- Generates and installs small POSIX shell scripts with minimal external dependencies
- Exposes instantaneous power readings in watts to Zabbix via UserParameters
- Works on both Intel/AMD CPUs with RAPL and various GPU types

## Architecture

### Components & Responsibilities

**Ansible**
- Detects power-related capabilities at deployment time
- Renders and deploys monitoring scripts to `/usr/local/share/zabbix_power_monitoring/`
- Generates Zabbix agent configuration at `/etc/zabbix/zabbix_agentd.d/power.conf`
- Does not install additional packages; only checks for presence

**Zabbix Agent**
- Loads `power.conf` and exposes UserParameters for:
  - `power.cpu.package0` (CPU package power)
  - `power.ram.package0` (RAM power)
  - `power.gpu[*]` (GPU power)
  - `power.redfish.platform` (Platform PSU power)
  - `power.gpu.discovery` (LLD JSON for GPU discovery)
  - `power.cpu.amd_hwmon` (AMD CPU power via hwmon, when available)

**Monitoring Scripts**
- POSIX shell (`bash`) scripts using standard Unix tools plus vendor CLIs if present
- Each script implements a single responsibility
- Returns exactly one numeric value in watts on success
- Exits non-zero with no output on failure

**Zabbix Server**
- Polls agent items at configured intervals (default 5s)
- Uses LLD rules for dynamic GPU components
- All server-side configuration is manual in this POC

## Repository Structure

```
.
├── ansible.cfg                 # Ansible configuration
├── inventory/hosts.ini         # Ansible inventory
├── playbooks/deploy-power-monitoring.yml   # Main playbook
├── roles/power_monitoring/     # Power monitoring role
│   ├── tasks/
│   │   ├── detect_rapl.yml         # CPU RAPL detection
│   │   ├── detect_ram_rapl.yml     # RAM RAPL detection
│   │   ├── detect_gpu_nvidia.yml   # NVIDIA GPU detection
│   │   ├── detect_gpu_amd.yml      # AMD GPU detection
│   │   ├── detect_redfish.yml      # Redfish detection
│   │   ├── deploy_scripts.yml      # Script deployment
│   │   └── main.yml                # Main orchestration
│   ├── templates/                  # Jinja2 templates for scripts
│   │   ├── read_cpu_rapl_power.sh.j2
│   │   ├── read_ram_rapl_power.sh.j2
│   │   ├── read_gpu_nvidia_power.sh.j2
│   │   ├── read_gpu_amd_power.sh.j2
│   │   ├── read_redfish_power.sh.j2
│   │   └── discover_gpu_sensors.sh.j2
│   └── vars/main.yml             # Default variables
├── group_vars/lostsecret_intel.yml   # Host group variables
└── host_vars/lostsecret-intel.yml      # Individual host variables
```

## Deployment

### Prerequisites

- Ansible installed on management host
- SSH access to target host (configured in `~/.ssh/config`)
- Zabbix agent installed and running on target host
- Python (for Ansible) on management host

### Configuration

#### Host Variables

Configure power monitoring behavior in `host_vars/lostsecret-intel.yml`:

```yaml
# Enable/disable monitoring components
power_monitoring_enable_cpu: auto      # auto|true|false
power_monitoring_enable_ram: auto      # auto|true|false
power_monitoring_enable_gpu: auto      # auto|true|false
power_monitoring_enable_redfish: auto  # auto|true|false

# Redfish settings (when enabled)
power_monitoring_redfish_bmc_url: "https://bmc.example.org"
power_monitoring_redfish_user: "monitor"
power_monitoring_redfish_password: !vault |
  # ansible-vault encrypted password
```

### Deployment Process

1. Configure SSH access in `~/.ssh/config`:
```
Host lostsecret-intel
  HostName <ip-or-dns-of-the-intel-box>
  User <your-user>
```

2. Run the deployment playbook:
```bash
ansible-playbook playbooks/deploy-power-monitoring.yml
```

## Supported Power Interfaces

### CPU Power (RAPL)
- Intel/AMD CPUs with RAPL support
- Reports CPU package power in watts
- Supports multiple CPU packages (package0, package1, etc.) 
- Uses microjoule sampling with 0.1s delay for accurate readings

### RAM Power (RAPL)
- RAPL domains supporting DRAM power
- Reports RAM power in watts (when available)
- Supports multiple RAM packages (package0, package1, etc.)
- Falls back gracefully if unsupported

### GPU Power
#### NVIDIA
- Uses `nvidia-smi` for power readings
- Requires NVIDIA drivers installed on host
- Supports multiple GPUs with index-based access

#### AMD
- Uses `rocm-smi` for power readings (preferred)
- Falls back to hwmon/sysfs interface
- Supports multiple GPUs with index-based access

### Platform Power (Redfish)
- Optional support for platform PSU power via Redfish/IPMI
- Requires BMC access and credentials
- Currently not fully implemented in this repository (placeholder script)

### AMD CPU Power via hwmon
- Alternative AMD CPU power detection via sysfs/hwmon
- Used as fallback when RAPL is not available
- Exposed via `power.cpu.amd_hwmon` UserParameter

## Monitoring Script Contracts

All scripts must:
- On success: Print exactly one line with a numeric value in watts, exit with code 0
- On failure: Print nothing, exit with non-zero code

## Zabbix Configuration

### Agent Configuration

Ansible generates `/etc/zabbix/zabbix_agentd.d/power.conf` with UserParameters like:
```ini
# CPU package power in watts (per package, Intel RAPL)
UserParameter=power.cpu.package0,/usr/local/share/zabbix_power_monitoring/read_cpu_rapl_power.sh 0

# RAM power in watts (per package DRAM RAPL domain)
UserParameter=power.ram.package0,/usr/local/share/zabbix_power_monitoring/read_ram_rapl_power.sh 0

# GPU power in watts, by index (NVIDIA or AMD)
UserParameter=power.gpu[*],/usr/local/share/zabbix_power_monitoring/read_gpu_power.sh "$1"

# Platform power via Redfish/IPMI (if supported)
UserParameter=power.redfish.platform,/usr/local/share/zabbix_power_monitoring/read_redfish_power.sh

# GPU Low-Level Discovery (LLD)
UserParameter=power.gpu.discovery,/usr/local/share/zabbix_power_monitoring/discover_gpu_sensors.sh
```

Note: The actual configuration will include parameters for all detected packages, not just package0.

### Zabbix Items and LLD Rules

Admins should configure:
1. LLD rules for GPU discovery using `power.gpu.discovery`
2. Items for CPU, RAM, GPU, and Redfish metrics
3. Update intervals (recommended: 5s)


## Troubleshooting

1. **Scripts not executing properly**: Check permissions on deployed scripts in `/usr/local/share/zabbix_power_monitoring/`
2. **Zabbix not detecting power metrics**: Validate that Zabbix agent is running and reloads the configuration
3. **Missing dependencies**: Ensure required tools (`nvidia-smi`, `rocm-smi`) are installed if monitoring GPUs
4. **Redfish not working**: Verify BMC credentials and network connectivity

## Security Considerations

- Scripts are deployed with minimal privileges
- No sudo/root escalation required
- Uses secure temporary file handling
- All components are designed to fail gracefully rather than crash