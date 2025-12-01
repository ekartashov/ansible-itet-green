#!/usr/bin/bash

INTERVAL="${1:-1}"
HOSTNAME="$(hostname)"

RAPL_BASE="/sys/class/powercap"
# shopt -s nullglob

zones=()
declare -A Z_NAME
declare -A Z_MAX

for z in "${RAPL_BASE}"/intel-rapl:*; do
    [ -d "$z" ] || continue
    if [ -f "$z/energy_uj" ]; then
        name=$(cat "$z/name" 2>/dev/null || echo "zone")
        max=$(cat "$z/max_energy_range_uj" 2>/dev/null || echo 0)
        zones+=("$z")
        Z_NAME["$z"]="$name"
        Z_MAX["$z"]="$max"
    fi
done

if [ "${#zones[@]}" -eq 0 ]; then
    echo "No RAPL zones found under ${RAPL_BASE}. This CPU probably doesn't expose RAPL."
    exit 1
fi

# read initial energies
declare -A E1
for z in "${zones[@]}"; do
    E1["$z"]=$(cat "$z/energy_uj")
done

echo "# timestamp,host,domain1:W,domain2:W,..."

for i in $(seq 10); do
    start_ts=$(date +%s)
    sleep "$INTERVAL"
    end_ts=$(date +%s)

    dt=$(( end_ts - start_ts ))
    if [ "$dt" -le 0 ]; then
        dt="$INTERVAL"   # assume integer INTERVAL
    fi

    declare -A E2
    for z in "${zones[@]}"; do
        E2["$z"]=$(cat "$z/energy_uj")
    done

    line="${end_ts},${HOSTNAME}"
    for z in "${zones[@]}"; do
        e_old=${E1["$z"]}
        e_new=${E2["$z"]}
        max=${Z_MAX["$z"]}

        if [ "$max" -gt 0 ] && [ "$e_new" -lt "$e_old" ]; then
            de=$(( e_new + max - e_old ))
        else
            de=$(( e_new - e_old ))
        fi

        watts=$(awk -v de="$de" -v dt="$dt" 'BEGIN {printf "%.3f", (de/1000000)/dt}')
        line+=",${Z_NAME[$z]}:${watts}"
    done

    echo "$line"

    # shift new → old
    for z in "${zones[@]}"; do
        E1["$z"]=${E2["$z"]}
    done
done
