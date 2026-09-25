#!/usr/bin/env bash
# Parallel balance simulation. Usage: tools/simulator/run_sim.sh <mode> <total_battles> [procs] [ai] [tag]
# mode: 1v1 (battles = per matchup), 3v3, 6v6
set -u
cd "$(dirname "$0")/../.."
MODE=${1:-3v3}; TOTAL=${2:-2000}; PROCS=${3:-4}; AI=${4:-heuristic}; TAG=${5:-$(date +%Y%m%d)}
godot --headless --path . --import >/dev/null 2>&1
mkdir -p reports/raw
PER=$(( TOTAL / PROCS ))
pids=()
for i in $(seq 1 $PROCS); do
  godot --headless --path . -s tools/simulator/simulate.gd -- mode=$MODE battles=$PER seed=$(( i * 7919 + RANDOM % 1000 )) ai=$AI out=reports/raw/${TAG}_${MODE}_${AI}_$i.json > reports/raw/${TAG}_${MODE}_${AI}_$i.log 2>&1 &
  pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done
python3 tools/simulator/report.py reports/raw/${TAG}_${MODE}_${AI}_*.json --out reports/balance_${TAG}_${MODE}.md
