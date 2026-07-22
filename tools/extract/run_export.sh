#!/usr/bin/env bash
# Batch-export all IB3 cooked packages with UE Viewer (umodel), headless.
# Runs INSIDE the i386 container (see run_export.md). Key flag: -ios (iOS textures).
# Meshes -> .psk/.pskx, animations -> .psa, textures -> .png, materials -> .mat/.props.txt.
set -u

# Configurable via env: UMODEL_FLAGS (extra flags), OUT_SUBDIR (output/log name).
CDIR=/data/extracted/Payload/SwordGame.app/CookedIPhone
SUB=${OUT_SUBDIR:-all}
XFLAGS=${UMODEL_FLAGS:-}
OUT=/data/exported/$SUB
LOG=/data/exported/$SUB.log
ERRLOG=/data/exported/$SUB.errors.log

mkdir -p "$OUT"
cp /data/tools/extract/umodel /usr/local/bin/umodel && chmod +x /usr/local/bin/umodel
cd "$CDIR" || exit 1

: > "$LOG"; : > "$ERRLOG"
total=$(ls -1 *.xxx 2>/dev/null | wc -l | tr -d ' ')
i=0
echo "START $(date) — $total packages" | tee -a "$LOG"

for pkg in *.xxx; do
  i=$((i+1))
  # Stop early if the mounted volume gets dangerously low (<1500 MB free).
  freem=$(df -Pm "$OUT" | awk 'NR==2{print $4}')
  if [ "${freem:-0}" -lt 1500 ]; then
    echo "ABORT at $i/$total: only ${freem}MB free on volume" | tee -a "$LOG" "$ERRLOG"
    break
  fi
  printf '[%d/%d] %s (free %sMB)\n' "$i" "$total" "$freem" >> "$LOG"
  if ! umodel -ios -export $XFLAGS -out="$OUT" "$pkg" >>"$LOG" 2>&1; then
    echo "WARN rc=$? : $pkg" >> "$ERRLOG"
  fi
done

echo "DONE $(date) — processed $i/$total" | tee -a "$LOG"
echo "output size:" | tee -a "$LOG"; du -sh "$OUT" | tee -a "$LOG"
