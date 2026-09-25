#!/usr/bin/env bash
cd "$(dirname "$0")/../.."
until grep -q ALL_DONE reports/raw/run_all_r1.log; do sleep 10; done
echo "r1 done $(date)"
tools/simulator/run_all.sh r2 > reports/raw/run_all_r2.log 2>&1
echo "r2 done $(date)"
