#!/usr/bin/env bash
cd "$(dirname "$0")/../.."
tools/simulator/run_sim.sh 6v6 12000 4 heuristic r9 > reports/raw/run_r9_6v6.log 2>&1
echo "6v6 done $(date)"
tools/simulator/run_sim.sh 1v1 100 4 heuristic r9 > reports/raw/run_r9_1v1.log 2>&1
echo "1v1 done $(date)"
