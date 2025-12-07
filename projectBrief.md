# Project Brief: Ansible-Based Power Monitoring for `lostsecret-intel`

## 1. Project Overview

This project is an engineering proof-of-concept for a **host-side**, **Ansible-driven** power monitoring framework that integrates with **Zabbix** via **simple agent polling** (UserParameters). It targets heterogeneous, university-style hardware where:

- Python and heavy tooling may not be available or desirable,
- Hardware configurations are custom and sometimes “weird”,
- Admins are sensitive to unexpected package installations or system changes.

The framework focuses on:

- Detecting available power interfaces at **deployment time**,
- Generating and installing small **POSIX shell** scripts with minimal external dependencies,
- Exposing **instantaneous power readings in watts** to Zabbix via **UserParameters**.

Initial targets:

- `lostsecret-intel` (local connection)
- `lostsecret-amd` (SSH)

The design is intended to generalize to additional hosts later.

---

## 2. Problem Statement, Scope & Non-Goals

### 2.1 Problem Statement

Collecting reliable power consumption data from heterogeneous, consumer-grade servers is difficult when:

- IPMI/BMC/Redfish support is limited or inconsistent,
- Different vendors expose power metrics through incompatible interfaces,
- Introducing new system packages is politically or operationally sensitive,
- Python or other heavy runtimes cannot be assumed to be present.

We want a **minimal-dependency, host-local** framework that configures Zabbix to read power metrics directly from each host, without cron jobs or custom daemons.

### 2.2 In-Scope (v1)

For this proof-of-concept, we target **instantaneous power** (in watts) for:

- **CPU package power** (Intel/AMD via RAPL)
- **RAM power** (RAPL domains where available)
- **GPU power**
  - NVIDIA via `nvidia-smi` if present
  - AMD via `rocm-smi` (or similar) and/or hwmon/sysfs
- **Platform/PSU power via Redfish/IPMI**, when:
  - A BMC/Redfish endpoint exists and
  - Required tools/Runtimes are already present

Each is reported as a **separate metric**. There is **no “total system power”** metric in v1.

### 2.3 Out of Scope (Non-Goals)

- Automatically installing vendor tools or system packages (e.g. `nvidia-smi`, `rocm-smi`, `jq`, `ipmitool`, Python modules).
- Cron jobs, long-running collectors, or `zabbix_sender`-based push architectures.
- Energy integration over time (Joules/Wh) or sophisticated modeling of PSU/board losses.
- Automated configuration of Zabbix server items/templates/triggers via API in this POC.
- Non-Linux hosts.

### 2.4 Rationale

- **Host-only scope** keeps the design acceptable to cautious university admins: no surprise installs, no daemons.
- **Separate metrics, no total** avoids misleading pseudo-accuracy; total power often needs calibrated hardware.
- **No cron/push** simplifies operation and failure modes; Zabbix already has a robust polling model.

---

## 3. Success Criteria

This proof-of-concept is considered successful if:

1. Running the main Ansible playbook on `lostsecret-intel`:
   - Detects available power interfaces (RAPL, GPUs, optionally Redfish),
   - Deploys monitoring scripts and Zabbix agent configuration,
   - Allows Zabbix admins to create items that yield valid instantaneous power readings in watts.

2. All monitoring scripts:
   - Output **exactly one numeric value in watts** on success (no labels, no units),
   - Produce **no output** and exit **non-zero** on failure,
   - Have negligible overhead at a **5-second** polling interval.

3. The same role can be applied to `lostsecret-amd` and additional hosts with minimal host-specific adjustments.

### Rationale

- These criteria are **observable**: either Zabbix graphs show sensible watt values or they don’t.
- Focusing on one concrete path (CPU RAPL → script → Zabbix item) ensures the design is grounded, not just aspirational.

---

## 4. System Architecture

### 4.1 Components & Responsibilities

**Ansible**

- Detects power-related capabilities at **deployment time**:
  - Intel/AMD RAPL domains
  - NVIDIA/AMD GPUs and vendor tools
  - Optional Redfish/IPMI endpoints
- Renders and deploys monitoring scripts under:
  - `/usr/local/share/zabbix_power_monitoring/`
- Generates Zabbix agent config:
  - `/etc/zabbix/zabbix_agentd.d/power.conf`
- Provides per-component feature toggles (`auto` / `true` / `false`).
- Does **not** install additional packages; only checks for presence.

**Zabbix Agent**

- Loads `power.conf` and exposes **UserParameters**, for example:
  - `power.cpu.package0`
  - `power.ram.total`
  - `power.gpu[*]`
  - `power.redfish.platform`
  - `power.gpu.discovery` (for LLD JSON)
- On request from the Zabbix server, executes the corresponding script and returns its stdout as the metric value.

**Monitoring Scripts**

- POSIX shell (`bash`) scripts using:
  - Standard tools (especially `sed`, `awk`, coreutils) plus vendor CLIs if present.
- Each script:
  - Implements a single responsibility (one interface, one reading),
  - Returns **one numeric watt value** on success,
  - Exits non-zero with **no output** on failure.

**Zabbix Server**

- Polls agent items at configured **Update intervals** (e.g. 5s).
- Configures **Low-Level Discovery (LLD)** rules for dynamic components (e.g. GPUs).
- All server-side configuration is done manually (for this POC) by admins.

### 4.2 Data Flow

1. Admin runs the Ansible playbook.
2. `roles/power_monitoring`:
   - Detects available interfaces,
   - Renders scripts and `power.conf`,
   - Reloads/restarts Zabbix agent if needed.
3. Zabbix server:
   - Uses discovery keys (e.g. `power.gpu.discovery`) for LLD,
   - Creates items such as `power.gpu[0]` based on discovery,
   - Polls items at defined intervals (default suggestion: 5s).
4. Scripts return instantaneous power readings in watts.

### Rationale

- **Deployment-time detection** keeps per-poll overhead low and removes the need for dynamic introspection in scripts.
- **UserParameters** are the simplest, most “Zabbix-native” integration point that fits your constraints (no push, no cron).
- **One numeric value contract** for scripts makes failure modes predictable and simplifies debugging.

---

## 5. Tools & Dependency Policy

### 5.1 Allowed Tools

Monitoring scripts may use:

- `bash` (POSIX shell, `#!/usr/bin/env bash`)
- Standard Unix tools:
  - `sed`, `awk`, `grep`, `cut`, `tr`, `cat`, `head`, `tail`, etc.
- Vendor tools **if already installed**:
  - `nvidia-smi`
  - `rocm-smi` or similar AMD GPU utilities
  - IPMI/Redfish CLIs where applicable

No scripts will **install** any tools; presence is treated as a capability signal.

### 5.2 Show-Stoppers & Special Cases

- If a script requires any **non-trivial** extra tool (e.g. `jq`, a Python module, or a vendor daemon) to reliably support a given interface, that must be treated as a **documented limitation**, not a silent dependency.
- Such a requirement must:
  - Be explicitly commented in the script and/or Ansible tasks,
  - Surface as a **warning or failure** during Ansible deployment, so the user/admin can make an explicit decision.

### 5.3 Python Usage

- Python is allowed **only in clearly isolated cases** where there is no sane shell alternative.
- The main expected use case is **Redfish/IPMI JSON handling**:
  - Ansible may deploy a small Python helper for Redfish,
  - If Python is missing or unusable:
    - In `auto` mode, Redfish monitoring is skipped with a warning,
    - In `true` mode, the role fails with a clear message.

### Rationale

- You’re operating in environments where you **cannot assume Python** or package management freedom.
- Allowing `sed`/`awk` without artificial limits keeps scripts concise and realistic, while the show-stopper rule forces explicit discussion when heavier tools are needed.
- Python is treated as an **exception**, not a default, which keeps the framework acceptable on tightly controlled systems.

---

## 6. Component Toggles & Semantics

Each monitored component is controlled by a tri-state variable:

- `power_monitoring_enable_cpu`
- `power_monitoring_enable_ram`
- `power_monitoring_enable_gpu`
- `power_monitoring_enable_redfish`

with values:

- `auto` (default)
- `true`
- `false`

### Behavior

- **`auto` (default)**  
  - Ansible attempts to detect support.
  - If detection succeeds → scripts + UserParameters are deployed.
  - If detection fails → component is skipped, a **warning** is emitted, but the role still succeeds.

- **`true` (force enable)**  
  - Ansible attempts to detect support.
  - If detection fails → the role **fails** with a clear error message  
    (e.g. “GPU power monitoring forced but no supported GPU interface found”).

- **`false` (force disable)**  
  - Detection is skipped.
  - No scripts/UserParameters for that component are deployed.

### Rationale

- `auto` gives “monitor what you can” behavior, which is practical for diverse hardware.
- `true` provides **fail-fast semantics** when a metric is critical to a deployment or experiment.
- `false` allows cleanly disabling noisy or unreliable components without code changes.

---

## 7. GPU & Redfish Strategies

### 7.1 GPU Power Measurement Strategy

Monitoring aims to support both NVIDIA and AMD GPUs.

**NVIDIA**

- Preferred method:
  - `nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits`
- If `nvidia-smi` is not available:
  - In `auto` mode → NVIDIA GPU power is “not available”; component skipped with a warning.
  - In `true` mode → role fails.

**AMD**

- First preference:
  - `rocm-smi` or equivalent AMD CLI if present.
- Second preference:
  - Sysfs/hwmon interfaces under:
    - `/sys/class/drm/card*/device/hwmon/hwmon*/power*_input`
- If no usable method is found:
  - `auto` → AMD GPU power skipped with warning.
  - `true` → role fails.

Scripts will:

- Enumerate available GPUs and methods at deploy time (via Ansible),
- Use an index-based interface for Zabbix (`power.gpu[*]`),
- Return a single numeric watt value for the requested GPU index.

### 7.2 Redfish/IPMI (Optional)

Redfish/IPMI monitoring is **opt-in**, enabled only when host vars specify it, e.g.:

```yaml
power_monitoring_enable_redfish: true
power_monitoring_redfish_bmc_url: "https://bmc.example.org"
power_monitoring_redfish_user: "monitor"
power_monitoring_redfish_password: !vault |
  # ansible-vault encrypted
```

At deployment time, Ansible:

* Validates connectivity and credentials as far as possible,
* Deploys a script that:

  * Uses `curl` (and optionally a Python helper) to query BMC/Redfish,
  * Extracts a single numeric power value in watts.

Failure modes:

* If prerequisites are missing and:

  * `auto` → Redfish is skipped with a warning.
  * `true` → role fails.

### Rationale

* GPU methods are chosen in **priority order** to maximize robustness without installing new tools.
* Redfish is kept **explicit and host-specific**, because BMC authentication and endpoint shapes vary; making it opt-in prevents accidental “half-working” integrations.

---

## 8. Zabbix Integration

### 8.1 Agent Configuration

Ansible renders `/etc/zabbix/zabbix_agentd.d/power.conf`, for example:

```ini
# CPU package power in watts
UserParameter=power.cpu.package0,/usr/local/share/zabbix_power_monitoring/read_cpu_rapl_power.sh

# RAM power in watts (if RAPL domain exists)
UserParameter=power.ram.total,/usr/local/share/zabbix_power_monitoring/read_ram_rapl_power.sh

# GPU power in watts, by index (NVIDIA or AMD)
UserParameter=power.gpu[*],/usr/local/share/zabbix_power_monitoring/read_gpu_power.sh "$1"

# Platform power via Redfish/IPMI (if supported)
UserParameter=power.redfish.platform,/usr/local/share/zabbix_power_monitoring/read_redfish_power.sh

# GPU Low-Level Discovery (LLD)
UserParameter=power.gpu.discovery,/usr/local/share/zabbix_power_monitoring/discover_gpu_sensors.sh
```

Ansible then reloads/restarts the Zabbix agent if this file changes.

### 8.2 Polling & Intervals

* Polling is fully controlled by the Zabbix server:

  * Each item has an **Update interval** (e.g. `5s`).
* The role defines a recommended interval:

  * `power_monitoring_recommended_poll_interval: 5s`
* Actual intervals are set by Zabbix admins when creating items or templates.

### 8.3 Low-Level Discovery (LLD)

* `discover_gpu_sensors.sh` outputs LLD JSON such as:

  ```json
  [
    { "{#GPU_INDEX}": "0", "{#GPU_VENDOR}": "NVIDIA" },
    { "{#GPU_INDEX}": "1", "{#GPU_VENDOR}": "NVIDIA" }
  ]
  ```

* Admins create an LLD rule:

  * Discovery key: `power.gpu.discovery`
  * Item prototype key: `power.gpu[{#GPU_INDEX}]`
  * Interval: e.g. 60–300s

This keeps Zabbix’s GPU list in sync with what Ansible-based deployment detects.

### Rationale

* Using **agent UserParameters** and **LLD** is idiomatic Zabbix; no extra plumbing.
* Separating “host-side deployment” (Ansible) from “server-side configuration” (admins) matches how real environments often work, and avoids requiring Zabbix API access.

---

## 9. Repository Structure

### 9.1 Inventory & Playbooks

* `inventory/hosts.ini`

  * Groups like `lostsecret_intel`, `lostsecret_amd`.
  * `lostsecret-intel` typically uses `ansible_connection=local`.
  * `lostsecret-amd` uses SSH.

* `playbooks/site.yml`

  * Applies `roles/base` and `roles/power_monitoring`.

* Helper script:

  * `scripts/run-ansible.sh` – wrapper around `ansible-playbook playbooks/site.yml`.

### 9.2 Roles

#### `roles/base`

* Generic baseline: common packages, time sync, basic configuration.
* Target architecture: **no power monitoring logic** here (legacy bits may exist temporarily, but should be migrated to `roles/power_monitoring`).

#### `roles/power_monitoring`

* **Tasks** (`roles/power_monitoring/tasks/`):

  * `main.yml` – orchestrates sub-tasks.
  * `detect_rapl.yml` – detect Intel/AMD RAPL domains.
  * `detect_gpu.yml` – detect GPUs and vendor tools.
  * `detect_redfish.yml` – detect Redfish/IPMI support if configured.
  * `deploy_scripts.yml` – install all required scripts to `/usr/local/share/zabbix_power_monitoring/`.
  * `deploy_agent_config.yml` – render `power.conf` and restart agent if needed.
  * `validate_readings.yml` (future) – optional checks that scripts return sane values.

* **Templates** (`roles/power_monitoring/templates/`):

  * `power.conf.j2`
  * `read_cpu_rapl_power.sh.j2`
  * `read_ram_rapl_power.sh.j2`
  * `read_gpu_nvidia_power.sh.j2`
  * `read_gpu_amd_power.sh.j2`
  * `read_redfish_power.sh.j2` (may call Python helper if needed)
  * `discover_gpu_sensors.sh.j2`

* **Variables**:

  * `roles/power_monitoring/vars/main.yml`:

    * `power_monitoring_enable_cpu: auto`
    * `power_monitoring_enable_ram: auto`
    * `power_monitoring_enable_gpu: auto`
    * `power_monitoring_enable_redfish: auto`
    * `power_monitoring_recommended_poll_interval: 5s`

* **Host/Group Vars**:

  * `host_vars/lostsecret-intel.yml`
  * `host_vars/lostsecret-amd.yml`
  * Overriding `power_monitoring_enable_*` or providing Redfish credentials.

### Rationale

* Explicit structure (role paths, file names) makes it easy for others to navigate the repo.
* Separating detection, deployment, and validation tasks keeps each piece small and testable.

---

## 10. Monitoring Scripts: Contracts & Performance

### 10.1 Output Contract

All scripts must:

* On success:

  * Print **exactly one line** with a single numeric value in watts:

    * Regex: `[0-9]+([.][0-9]+)?`
  * Exit with code `0`.

* On failure (missing interface, parse error, missing tool, etc.):

  * Print **nothing**.
  * Exit with a **non-zero** code.

Zabbix will then:

* Interpret persistent failures as “item not supported”,
* Allow admins to distinguish “sensor broken/missing” from “zero power”.

### 10.2 Performance Constraints

* Scripts must be cheap enough to run at **5-second** intervals.
* All heavy enumeration (e.g. `lspci`, `dmidecode`) is restricted to **Ansible deployment time**, not per-poll.
* Per-poll scripts should:

  * Read only a small number of sysfs files or run a single vendor CLI,
  * Avoid large file scans or expensive subprocess pipelines.

### Rationale

* The strict output contract simplifies Zabbix preprocessing and debugging.
* Zero output + non-zero exit clearly separates “no data” from “0 watts”.
* Separating discovery (Ansible) from polling (Zabbix) prevents performance surprises.

---

## 11. Execution Flow

1. **Deployment**

   * Admin runs:

     ```bash
     ./scripts/run-ansible.sh
     ```

   * `playbooks/site.yml`:

     * Applies `roles/base`,
     * Applies `roles/power_monitoring` to `lostsecret-intel` (local) and `lostsecret-amd` (SSH).

2. **Detection & Config**

   * `roles/power_monitoring`:

     * Detects RAPL, GPUs, optional Redfish based on `power_monitoring_enable_*`.
     * Renders and installs scripts.
     * Renders `/etc/zabbix/zabbix_agentd.d/power.conf`.
     * Reloads/restarts Zabbix agent if needed.

3. **Zabbix Setup (manual in POC)**

   * Admins configure:

     * LLD rules (e.g. for GPUs via `power.gpu.discovery`),
     * Items for CPU, RAM, GPU, Redfish metrics,
     * Update intervals (default suggestion: 5s).

4. **Monitoring**

   * Zabbix server polls items,
   * Scripts return numeric watt values,
   * Power graphs populate.

---

## 12. Validation & Testing

### 12.1 Functional Validation via Ansible

`roles/power_monitoring/tasks/validate_readings.yml` (planned) will:

* Execute each deployed script directly on the host.
* Check that:

  * Exit code is `0` on success,
  * Output matches the numeric regex.
* Emit warnings or failures when scripts misbehave.

### 12.2 Automated Testing (Future)

* BATS-based tests under `roles/power_monitoring/tests/` to validate:

  * Parsing of vendor CLI output,
  * Behavior on missing sysfs paths,
  * Error handling and exit codes.

### Rationale

* Running scripts via Ansible at deploy time catches misconfiguration early.
* BATS gives a simple, dependency-light way to regression-test parsing and edge cases later.

---

## 13. Limitations & Risks

* Accuracy is limited by vendor-provided sensors (RAPL, GPU tools, Redfish).
* Some hardware may expose **no usable power metrics** at all; the framework will then:

  * Skip those components in `auto` mode,
  * Fail in `true` mode as configured.
* Dynamic frequency scaling and power management cause noisy readings; no smoothing is performed at script level.
* Zabbix server misconfiguration (wrong intervals, thresholds, or preprocessing) is out of scope for this POC.

---

## 14. Conclusion

This brief defines a minimal yet robust architecture for **Ansible-managed, Zabbix-polled power monitoring** on heterogeneous Linux hosts. Key characteristics:

* **Host-local, conservative** changes: no surprise package installs or daemons.
* **Zabbix-native integration** via UserParameters and LLD.
* **Clear contracts** for scripts, toggles, and dependencies.
* A structure that can:

  * Start small (CPU RAPL on `lostsecret-intel`),
  * Grow to GPUs and Redfish,
  * Scale to multiple hosts without undermining maintainability.

The design is intentionally explicit about **why** certain choices were made (polling vs push, no cron, shell-first, Python-as-exception), so that future contributors and admins can understand the trade-offs and extend the framework without guessing the original intent.