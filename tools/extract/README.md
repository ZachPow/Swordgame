# IB3 asset extraction pipeline

Extracts meshes, animations, textures, and materials from the Infinity Blade III
iOS bundle (`extracted/Payload/SwordGame.app/CookedIPhone/`, UE3 / Engine build
13249) using Gildor's **UE Viewer (umodel)**.

## Why the container

- umodel has **no macOS build**; the Linux build is a **32-bit x86 (i386)** ELF.
- Host is Apple Silicon (M2). We run it in an **i386 Debian container** under
  **Colima** (`--vm-type vz --vz-rosetta`); the i386 binary executes via qemu-i386.
- The image (`Dockerfile`) adds umodel's runtime deps incl. the long-removed
  **libpng12** (i386), supplied as `libpng12.so.0`, plus Xvfb (not needed for
  export, kept for the optional viewer).

## Critical flags

- `-ios` — **required**. IB3 textures are iOS-cooked; without this umodel writes
  0-byte textures. With it, mips are read from the `.tfc` caches and decoded.
- `-png` — textures as PNG. (`-dds` does NOT passthrough here — iOS textures
  decode to full-res regardless, so DDS gives no size win.)
- `-notex` / `-nomesh` / `-noanim` / `-nostat` — class filters used to split passes.
- Animations: glTF anim export needs the interactive viewer, so batch exports use
  native **.psa** (convert to glTF/FBX later in Blender).

## Passes

1. **Geometry + animation** (`run_export.sh` with `UMODEL_FLAGS=-notex`,
   `OUT_SUBDIR=geo`): meshes → `.pskx`/`.psk`, animations → `.psa`, materials →
   `.mat`/`.props.txt`. Small; safe on disk.
2. **Textures** (`run_textures.sh`, host-side): exports PNG in chunks and
   downscales each chunk with `sips` (cap longest side at `MAXDIM`, default 1024)
   before moving to `exported/textures/`. Keeps peak disk bounded — full-res PNG of
   every texture would be ~30 GB.

`monitor.sh` is a safety watchdog: stops the export container if the Mac drops
below 2 GB free (a full disk breaks the tooling).

## Build & run

```bash
colima start --vm-type vz --vz-rosetta --cpu 4 --memory 6 --disk 25
docker build --platform linux/386 -t umodel-env-i386 tools/extract

# pass 1
docker run -d --name ib3geo --platform linux/386 \
  -e OUT_SUBDIR=geo -e UMODEL_FLAGS="-notex" \
  -v "$PWD:/data" umodel-env-i386 bash /data/tools/extract/run_export.sh

# pass 2 (after pass 1)
MAXDIM=1024 bash tools/extract/run_textures.sh
```

## Output layout (`exported/`)

```
geo/<Package>/SkeletalMesh3/<Mesh>.pskx|psk   # + .props.txt
geo/<Package>/AnimSet/<Anim>.psa
geo/<Package>/.../*.mat, *.props.txt          # material params
textures/<Package>/Texture2D/<Tex>.png        # downscaled
```

Next stage: convert `.psk/.pskx/.psa` → glTF/FBX in Blender (io_scene_psk_psa
addon) for UE5 import; rebuild UE3 materials from the exported params + textures.
