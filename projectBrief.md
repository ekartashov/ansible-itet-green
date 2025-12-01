# Project Brief: Ansible Automation for lostsecret-intel

## Project Overview

This Ansible project represents an engineering proof-of-concept for developing a resilient framework for power consumption monitoring of server systems. The project focuses on establishing a working prototype that can reliably collect power data across diverse hardware configurations using bash scripts with minimal dependencies.

## Engineering Objectives

1. **Resilient Power Monitoring Framework**: Develop a robust system capable of collecting power consumption data from various hardware components using bash scripts with minimal dependencies
2. **Cross-Hardware Compatibility**: Create a solution that works across different server configurations, particularly focusing on systems where Python may not be available
3. **Dependency-Free Scripting**: Demonstrate the feasibility of using pure bash with standard Unix tools (sed, awk, grep, etc.) for power data collection

## Technical Approach

### Engineering Methodology
This project implements a bash-based approach to power monitoring that prioritizes reliability and minimal dependencies:
- **Primary Methods**: Direct hardware interface access using Intel RAPL and AMD RAPL interfaces
- **Secondary Methods**: Alternative monitoring approaches when primary methods fail
- **Fallback Strategies**: Approximate calculations from individual components when direct access is unavailable

### Project Structure
- **Inventory Management**: Uses Ansible inventory with a single host group `lostsecret_intel`
- **Configuration Management**: Implements Ansible roles for modular configuration management
- **Playbook Execution**: Main playbook `playbooks/site.yml` orchestrates the configuration process
- **Variable Management**: Separates host-specific and group-wide variables for flexible configuration

### Key Components

#### Base Role (`roles/base`)
- **System Baseline**: Applies consistent system configurations across the target host
- **Multi-Method Monitoring**: Implements fallback strategies for power consumption monitoring using bash scripts
- **Script Integration**: Integrates various system monitoring scripts for different monitoring approaches

#### Power Monitoring Scripts
- **RAPL Monitoring** (`get_power_rapl.bash`): Primary method using Intel's RAPL interface
- **AMD RAPL Support**: Implementation for AMD CPU power monitoring
- **Component-Level Monitoring**: Designed to work with different hardware components and provide approximate totals when direct access fails

### Target System
- **Host Name**: `lostsecret-intel`
- **Connection Method**: Local connection (ansible_connection=local)
- **Target Platform**: Consumer-grade hardware with limited IPMI support

## Implementation Details

### Current Configuration
- **Main Playbook**: `playbooks/site.yml` targets the `lostsecret_intel` group
- **Base Role**: Applied to all target systems for consistent baseline configuration
- **Power Monitoring**: Configured with multiple approaches to ensure data collection regardless of hardware limitations

### Execution Flow
1. Ansible connects to the `lostsecret-intel` host
2. Executes the base role tasks
3. Attempts primary power monitoring methods (Intel RAPL, AMD RAPL)
4. Falls back to alternative methods when primary approaches fail
5. Outputs power consumption data in CSV format with timestamps

## Engineering Significance

This project demonstrates an engineering approach to power monitoring that:
- Proves the viability of bash-based power monitoring in environments where Python may not be available
- Establishes a methodology for collecting reliable power data using only standard Unix tools
- Provides a framework for future research into energy efficiency studies
- Documents the challenges and solutions encountered when working with consumer-grade server hardware

## Future Development Considerations

### Engineering Extensions
1. **Enhanced Fallback Logic**: Improve the decision-making process for selecting the most reliable monitoring method
2. **Data Aggregation**: Develop methods for combining data from multiple sources for more accurate totals
3. **Hardware Profiling**: Create a system to automatically detect and classify hardware components for optimal monitoring approaches
4. **Performance Analysis**: Study the overhead of different monitoring methods on system performance

### Scalability Considerations
- The current setup is designed for a single host but can be extended to multiple hosts for research purposes
- Modular role structure supports easy extension for additional system components
- Variable management supports both single-host and multi-host configurations for research studies

## Dependencies and Prerequisites

### System Requirements
- Linux system with RAPL support (Intel/AMD CPUs) or alternative power monitoring interfaces
- Standard Unix tools (bash, sed, awk, grep) available
- Ansible 2.9+ installed
- SSH access configured for the target host

### Ansible Configuration
- Uses local connection method for direct system access
- Requires proper SSH configuration in `~/.ssh/config`
- Default inventory file: `inventory/hosts.ini`
- Main playbook: `playbooks/site.yml`

## Usage Instructions

### Basic Execution
```bash
# Run the main playbook
./scripts/run-ansible.sh

# Run with verbose output
./scripts/run-ansible.sh -vv

# Override limit via environment variable
LIMIT=lostsecret_intel ./scripts/run-ansible.sh -vv
```

### Customization
- Modify `host_vars/lostsecret-intel.yml` for host-specific variables
- Adjust `group_vars/lostsecret_intel.yml` for group-wide settings
- Uncomment and configure alternative monitoring methods in `roles/base/tasks/main.yml`

## Engineering Methodology and Validation

### Approach Validation
The project emphasizes validating the effectiveness of different monitoring approaches:
- Testing primary methods (RAPL, AMD RAPL) on various hardware configurations
- Documenting failures and fallback success rates
- Measuring data consistency and reliability across different approaches

### Data Collection Strategy
- Continuous monitoring with configurable intervals
- Multiple data sources for cross-validation
- Timestamped data for temporal analysis
- Hierarchical data collection that adapts to available hardware interfaces

## Conclusion

This Ansible-based engineering project provides a proof-of-concept for reliable power consumption monitoring in heterogeneous computing environments. By implementing a bash-scripted approach with robust fallback mechanisms and minimal dependencies, it addresses the challenge of collecting power data from systems where Python availability cannot be guaranteed. The framework serves as a foundation for future research into energy efficiency in university computing environments.
