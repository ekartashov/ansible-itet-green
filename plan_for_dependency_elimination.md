# Plan for Eliminating All Dependencies in Intel RAPL Script

## Current Dependencies to Eliminate

1. **cat** - for reading files
2. **date** - for getting timestamps
3. **bc** - for floating-point calculations
4. **seq** - for loop iteration
5. **awk** - for text processing

## Goal

Create a version of the Intel RAPL script that uses only bash builtins:
- Parameter expansion
- Arithmetic expansion
- String manipulation
- Redirection
- Pattern matching
- Looping constructs

## Solution Approach

### 1. Replace `cat` with Redirection

**Current:**
```bash
name=$(cat "$z/name")
max=$(cat "$z/max_energy_range_uj")
```

**Replacement:**
```bash
name=$(<"$z/name")
max=$(<"$z/max_energy_range_uj")
```

### 2. Replace `date` for Timestamps

**Current:**
```bash
start_ts=$(date +%s)
end_ts=$(date +%s)
```

**Replacement:**
Use bash's built-in arithmetic with SECONDS variable and process uptime from /proc/self/stat

**Solution:**
```bash
# Read process start time from /proc/self/stat
IFS=' ' read -r -a stat_parts < /proc/self/stat
start_time=${stat_parts[21]}  # 22nd field is start time in clock ticks

# Convert clock ticks to seconds (assuming HZ=100 for most systems)
start_ts=$(( start_time / 100 ))

# For end time, use the same approach or calculate delta from start_ts
end_ts=$(( start_ts + INTERVAL ))
```

### 3. Replace `bc` for Floating-Point Calculations

**Current:**
```bash
watts=$(bc <<< "scale=3; $de / 1000000 / $dt")
```

**Replacement:**
Use integer arithmetic with scaling

**Solution:**
```bash
# Calculate watts with integer arithmetic
# Multiply by 1000 to preserve 3 decimal places, then divide
# watts = (de * 1000) / (dt * 1000) = de / dt
watts=$(( de * 1000 / dt / 1000 ))
```

### 4. Replace `seq` for Loop Iteration

**Current:**
```bash
for i in $(seq 10); do
```

**Replacement:**
Use a bash while loop

**Solution:**
```bash
count=0
while [ "$count" -lt 10 ]; do
  # ... loop body ...
  count=$((count + 1))
done
```

### 5. Replace `awk` for Text Processing

**Current:**
```bash
awk -F, -v de="$de" -v dt="$dt" 'BEGIN {printf "%.3f", (de/1000000)/dt}'
```

**Replacement:**
Use bash string manipulation and arithmetic

**Solution:**
```bash
# Already handled by the integer arithmetic approach above
```

## Complete Implementation Plan

### Step 1: File Reading

Use redirection instead of `cat`:
```bash
name=$(<"$z/name")
max=$(<"$z/max_energy_range_uj")
```

### Step 2: Timing

Use /proc/self/stat for process start time:
```bash
IFS=' ' read -r -a stat_parts < /proc/self/stat
start_time=${stat_parts[21]}
start_ts=$(( start_time / 100 ))
```

### Step 3: Calculations

Use integer arithmetic with scaling:
```bash
watts=$(( de * 1000 / dt / 1000 ))
```

### Step 4: Looping

Use a while loop instead of `seq`:
```bash
count=0
while [ "$count" -lt 10 ]; do
  # ... loop body ...
  count=$((count + 1))
done
```

### Step 5: String Processing

Use bash parameter expansion and pattern matching:
```bash
# Already handled by the integer arithmetic approach
```

## Challenges and Trade-offs

1. **Precision**: Floating-point calculations with integer arithmetic will be less precise
2. **Portability**: Using /proc/self/stat is Linux-specific
3. **Readability**: Bash-only solutions can be more complex to read and maintain
4. **Performance**: Integer arithmetic is faster but less flexible

## Benefits

1. **Minimal Dependencies**: Only uses bash builtins
2. **Portability**: No external commands to install or configure
3. **Reliability**: Fewer points of failure
4. **Security**: Reduced attack surface

## Conclusion

This plan outlines a comprehensive approach to eliminating all dependencies in the Intel RAPL script by using only bash builtins. The trade-offs are primarily in precision and portability, but the benefits of minimal dependencies and increased reliability make this approach worthwhile for environments where external command availability cannot be guaranteed.