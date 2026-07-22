#!/usr/bin/env bash
# External safety monitor: watch Mac free space; stop the export container
# before the disk gets full enough to break the tool harness (<2000 MB).
set -u
LOG=/Users/zacharypower/Desktop/dev/InfinityBlade/exported/monitor.log
: > "$LOG"
while docker ps --filter name=ib3export --format '{{.Names}}' | grep -q ib3export; do
  freem=$(df -Pm / | awk 'NR==2{print $4}')
  echo "$(date +%H:%M:%S) free=${freem}MB out=$(du -sm /Users/zacharypower/Desktop/dev/InfinityBlade/exported/all 2>/dev/null | awk '{print $1}')MB" >> "$LOG"
  if [ "${freem:-0}" -lt 2000 ]; then
    echo "$(date +%H:%M:%S) LOW SPACE (${freem}MB) — stopping ib3export" >> "$LOG"
    docker stop ib3export >> "$LOG" 2>&1
    break
  fi
  sleep 20
done
echo "$(date +%H:%M:%S) monitor exit (container stopped or gone)" >> "$LOG"
