#!/usr/bin/env bash
# Full Phase-2 validation batch: (b) 3v3 20000 battles, then (a) 1v1 100 battles per set matchup.
set -u
cd "$(dirname "$0")/../.."
TAG=${1:-$(date +%Y%m%d)}
tools/simulator/run_sim.sh 3v3 20000 4 heuristic $TAG
tools/simulator/run_sim.sh 1v1 100 4 heuristic $TAG
echo ALL_DONE
