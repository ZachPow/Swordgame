#!/usr/bin/env bash
# HOST-side texture pass. Exports IB3 textures in chunks, downscales each chunk
# with macOS `sips` (cap longest side at MAXDIM), then moves them into the final
# tree — so peak disk stays bounded instead of ballooning to ~30 GB of full-res PNG.
#
# Env: MAXDIM (default 1024), CHUNK packages per batch (default 80).
set -u
ROOT=/Users/zacharypower/Desktop/dev/InfinityBlade
CDIR="$ROOT/extracted/Payload/SwordGame.app/CookedIPhone"
STAGE="$ROOT/exported/_texstage"
FINAL="$ROOT/exported/textures"
MAXDIM=${MAXDIM:-1024}
CHUNK=${CHUNK:-80}

mkdir -p "$FINAL"
# bash 3.2 (macOS default) has no mapfile — load the array portably.
pkgs=()
while IFS= read -r line; do pkgs+=("$line"); done < <(cd "$CDIR" && ls -1 *.xxx)
total=${#pkgs[@]}
echo "texture pass: $total packages, chunk=$CHUNK, maxdim=$MAXDIM"

i=0
while [ $i -lt $total ]; do
  batch=("${pkgs[@]:i:CHUNK}")
  rm -rf "$STAGE"; mkdir -p "$STAGE"

  # Export textures only (skip geometry/anim already captured in the geo pass).
  docker run --rm --platform linux/386 -v "$ROOT:/data" umodel-env-i386 bash -lc "
    cp /data/tools/extract/umodel /usr/local/bin/umodel && chmod +x /usr/local/bin/umodel
    cd /data/extracted/Payload/SwordGame.app/CookedIPhone
    for p in ${batch[*]}; do
      umodel -ios -export -png -nomesh -noanim -nostat -out=/data/exported/_texstage \"\$p\" >/dev/null 2>&1 || true
    done
  " >/dev/null 2>&1

  # Downscale in place (only if wider than MAXDIM — never upscale), then move.
  while IFS= read -r f; do
    w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')
    if [ "${w:-0}" -gt "$MAXDIM" ]; then sips -Z "$MAXDIM" "$f" >/dev/null 2>&1; fi
  done < <(find "$STAGE" -name '*.png')

  while IFS= read -r rel; do
    mkdir -p "$FINAL/$(dirname "$rel")"
    mv -f "$STAGE/$rel" "$FINAL/$rel"
  done < <(cd "$STAGE" && find . -type f)

  i=$((i+CHUNK))
  echo "  processed $i/$total  final=$(du -sm "$FINAL" 2>/dev/null | awk '{print $1}')MB  free=$(df -Pm / | awk 'NR==2{print $4}')MB"
done
rm -rf "$STAGE"
echo "texture pass DONE. final size: $(du -sh "$FINAL" | awk '{print $1}')"
