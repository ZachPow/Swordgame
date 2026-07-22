#!/usr/bin/env bash
# HOST-side material-capture pass. Materials only export when their textures load
# (-notex suppresses them), so we export with textures to a staging dir, keep only
# the tiny material files (.mat / .props.txt with the diffuse/normal/spec mapping),
# and discard the re-decoded texture images. Chunked to bound peak disk.
set -u
ROOT=/Users/zacharypower/Desktop/dev/InfinityBlade
CDIR="$ROOT/extracted/Payload/SwordGame.app/CookedIPhone"
STAGE="$ROOT/exported/_matstage"
FINAL="$ROOT/exported/materials"
CHUNK=${CHUNK:-80}

mkdir -p "$FINAL"
pkgs=()
while IFS= read -r line; do pkgs+=("$line"); done < <(cd "$CDIR" && ls -1 *.xxx)
total=${#pkgs[@]}
echo "material pass: $total packages, chunk=$CHUNK"

i=0
while [ $i -lt $total ]; do
  batch=("${pkgs[@]:i:CHUNK}")
  rm -rf "$STAGE"; mkdir -p "$STAGE"

  docker run --rm --platform linux/386 -v "$ROOT:/data" umodel-env-i386 bash -lc "
    cp /data/tools/extract/umodel /usr/local/bin/umodel && chmod +x /usr/local/bin/umodel
    cd /data/extracted/Payload/SwordGame.app/CookedIPhone
    for p in ${batch[*]}; do
      umodel -ios -export -nomesh -noanim -nostat -out=/data/exported/_matstage \"\$p\" >/dev/null 2>&1 || true
    done
  " >/dev/null 2>&1

  # Keep only material files (MaterialInstanceConstant / Material* dirs); drop textures.
  while IFS= read -r rel; do
    mkdir -p "$FINAL/$(dirname "$rel")"
    mv -f "$STAGE/$rel" "$FINAL/$rel"
  done < <(cd "$STAGE" && find . -type f \( -path '*Material*' \))

  i=$((i+CHUNK))
  echo "  processed $i/$total  materials=$(find "$FINAL" -name '*.mat' | wc -l | tr -d ' ')  free=$(df -Pm / | awk 'NR==2{print $4}')MB"
done
rm -rf "$STAGE"
echo "material pass DONE. .mat files: $(find "$FINAL" -name '*.mat' | wc -l | tr -d ' ')  size: $(du -sh "$FINAL" | awk '{print $1}')"
