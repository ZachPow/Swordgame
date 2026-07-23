# Blender → Unreal Engine 5 conversion — session handoff

**Purpose of this file:** a complete, standalone brief so a fresh Claude Code
session (or a human) can pick up the mesh/animation conversion with zero prior
context. Read this top-to-bottom, then jump to **"Start here (next session)"**.

---

## 1. Project context

Rebuilding **Infinity Blade III** (ChAIR/Epic, 2013, iOS-only, UE3; delisted 2018,
removed 2020) as a **UE5 remake**. Non-commercial preservation project. Gameplay
code will be written fresh; assets/data come from the user's own copy of the game
plus Epic's free Fab Infinity Blade packs. Full project plan is in `plan.md`;
scope target is a *content-complete core loop for one region* built systems-first.

**Where the project stands:** asset **extraction is 100% done**. The IB3 IPA was
unzipped and all 1,288 cooked UE3 packages were run through UE Viewer (umodel) in
an i386 container. Output lives in `exported/`. This conversion step —
**Phase 1b.2** of `plan.md` — is the next piece of work and the subject of this
file. Nothing downstream (UE5 project, gameplay) exists yet.

## 2. What this step solves

`exported/` holds Unreal-*native* intermediate formats UE5 **cannot import directly**:

| Source (`exported/…`)                     | Format | UE5 direct? | Path to UE5            |
|-------------------------------------------|--------|-------------|------------------------|
| `geo/<pkg>/SkeletalMesh3/*.psk`           | PSK    | ❌          | Blender → FBX          |
| `geo/<pkg>/StaticMesh3/*.pskx`            | PSKX   | ❌          | Blender → FBX          |
| `geo/<pkg>/AnimSet/*.psa`                 | PSA    | ❌          | Blender → FBX          |
| `textures/<pkg>/Texture2D/*.png`          | PNG    | ✅          | import as-is           |
| `materials/<pkg>/**/*.mat` + `.props.txt` | text   | ✅ (read)   | rebuild in UE5         |

Blender bridges **meshes + animations only** (PSK/PSA → FBX). Textures import
straight into UE5; materials are rebuilt UE5-side from the `.props.txt` wiring.
Neither textures nor materials go through Blender.

## 3. Environment / machine facts (verified 2026-07-22)

- **Machine:** Apple M2, macOS 26.x. Dev repo at
  `/Users/zacharypower/Desktop/dev/InfinityBlade`.
- **Blender: NOT INSTALLED.** (An earlier note claimed `/Applications/Blender.app`
  but it is not present — confirmed absent from /Applications, Homebrew, and disk.)
  **First prerequisite is to install it** (see §5). Any Blender 3.x/4.x works.
- **Extracted data (source for this step), on the Mac:**
  - `exported/geo/` — 761 skeletal `.psk`, 2,415 static `.pskx`, 690 `.psa`
    animation sets, organized as `geo/<packageName>/{SkeletalMesh3,StaticMesh3,AnimSet}/`.
  - `exported/textures/` — 7,495 PNGs (≤1024px). `exported/materials/` — 2,891
    `.mat` + `.props.txt`. Total `exported/` ≈ 6.6 GB.
  - `exported/INVENTORY.md` documents counts/layout; `tools/extract/README.md`
    documents how extraction was done (re-run at `MAXDIM=2048` for hero textures).
- **Git:** the project is its **own** git repo (independent of the home-dir repo).
  Remote `origin` = `https://github.com/ZachPow/Swordgame.git`, branch `main`.
  `gh` is authenticated (account zach746, repo scope). **Committed:** code,
  `tools/extract/` scripts, `plan.md`, `blender.md`, `exported/INVENTORY.md`.
  **Gitignored (never commit):** `exported/`, `extracted/`, `*.ipa`,
  `converted/`, umodel binaries, logs. Legal guardrail: extracted IB3 assets and
  the game bundle are never committed or distributed — only code, mined data
  JSON, and Fab content are shareable.
- **In-flight:** the user is moving to another PC. A background `rsync` is copying
  `exported/` (6.6 GB) + the 1.8 GB IPA to an external **FAT32** drive
  (`/Volumes/NO NAME/`). Conversion can run on whichever machine has Blender +
  `exported/geo/` — Mac (after installing Blender) or the new PC.

## 4. How Claude Code can automate this (important — read before starting)

Claude Code can drive nearly all of this itself, headless:

1. **Run Blender from the CLI:**
   `<BLENDER_BIN> --background --python script.py -- <args>`. Write the script,
   run it via Bash, read the log, fix, rerun — the normal edit/run loop.
2. **Install the PSK/PSA addon headlessly** via a one-off script
   (`bpy.ops.preferences.addon_install(filepath=zip)` +
   `bpy.ops.preferences.addon_enable(module="io_scene_psk_psa")`) — no GUI needed.
3. **Probe operator signatures** for the installed addon version by printing
   `bpy.ops.import_scene.psk.get_rna_type().properties` — do this before writing
   the batch, since params drift between addon versions.
4. **Verify visually without a GUI:** import an asset headless, point a camera at
   it, render to PNG, then **Read the PNG** (Claude can view images) to check
   orientation/scale/skinning and catch a 90° rotation or bad scale. This
   replaces eyeballing the viewport for the proof-of-concept.
5. **Optional live Blender via MCP:** the "Blender MCP" addon runs a socket
   server inside a live Blender session; Claude Code connects as an MCP client and
   can send Python + get viewport screenshots. More setup (third-party — verify
   current install steps); only worth it for interactive scene work, not batch.

**Recommended: headless for everything.** MCP only if interactive editing is
wanted later.

## 5. Prerequisites

1. **Install Blender.** Easiest: `brew install --cask blender` (or download from
   blender.org). Then the binary is at
   `/Applications/Blender.app/Contents/MacOS/Blender`. **Verify** with
   `.../Blender --version` before scripting — do not assume the path exists.
2. **Get the `io_scene_psk_psa` addon** (Colin Basnett / DarklightGames):
   download the release zip from
   https://github.com/DarklightGames/io_scene_psk_psa , then install+enable it
   (headless per §4.2, or GUI: Preferences → Add-ons → Install…). Provides
   operators `import_scene.psk`, `import_scene.psa`, and PSK/PSA export.

## 6. Data map — what pairs with what

A skeletal mesh and its animations must share a skeleton:

- `SkeletalMesh3/*.psk` carries the mesh **and** its skeleton (bones + skin weights).
- `AnimSet/*.psa` carries animation curves for a **specific** skeleton.
- Shared animation banks live in packages suffixed `*_Animset_SF`; character
  packages (`BOSS_*`, hero rigs) carry the matching skeleton.
- Package-name prefixes: `BOSS_*` enemies, `IB3_Wp_*`/`B_*`/`SA_*` weapons & gear,
  `A0x_*`..`L0x_*` arenas/locales, `CFX_*` cinematic/FX, `IB1_`/`IB2_` shared
  legacy content.

**Conversion rule:** import a `.psk` first (establishes the armature), import the
PSA(s) for that skeleton onto it, export one FBX with mesh + actions. Static
`.pskx` have no skeleton → one-to-one convert.

## 7. Phase A — Manual proof-of-concept (DO THIS FIRST, once)

Prove the whole chain on ONE hero asset (a `BOSS_*` package) before automating.
Claude can do all of this headless + render-to-PNG to verify.

1. Fresh empty scene.
2. Import the `SkeletalMesh3/*.psk` → expect mesh + armature.
3. With armature active, import a matching `AnimSet/*.psa` → sequences become Actions.
4. **Check orientation & scale** (render to PNG and look): upright, sensible
   facing, ~human height. Record any rotation/scale fix needed.
5. Export FBX: Selected Objects; Object Types = Armature+Mesh; Add Leaf Bones OFF;
   Bake Animation ON; Apply Scalings = FBX All; Forward = -Z, Up = Y.
6. Import the FBX into a UE5 project: Skeletal Mesh + create skeleton, Import
   Animations ON; set Import Uniform Scale if step 4 showed a mismatch (UE = cm).
   Confirm mesh renders, skeleton sane, animation plays.

Lock in the exact export settings + scale/rotation fix — those constants feed the
batch script.

## 8. Phase B — Headless batch conversion

Save as `tools/convert/psk_to_fbx.py`; run:

```bash
<BLENDER_BIN> --background --python tools/convert/psk_to_fbx.py -- \
  --in exported/geo --out converted/fbx
```

Script skeleton (validate operator params in Phase A first):

```python
import bpy, sys, os, glob, argparse

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def convert_package(pkg_dir, out_dir):
    pkg = os.path.basename(pkg_dir)
    psk_dir  = os.path.join(pkg_dir, "SkeletalMesh3")
    pskx_dir = os.path.join(pkg_dir, "StaticMesh3")
    anim_dir = os.path.join(pkg_dir, "AnimSet")

    for psk in glob.glob(os.path.join(psk_dir, "*.psk")):
        reset_scene()
        bpy.ops.import_scene.psk(filepath=psk)                  # mesh + armature
        arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
        if arm:
            bpy.context.view_layer.objects.active = arm
            for psa in glob.glob(os.path.join(anim_dir, "*.psa")):
                bpy.ops.import_scene.psa(filepath=psa)          # actions onto armature
        name = os.path.splitext(os.path.basename(psk))[0]
        out = os.path.join(out_dir, pkg, "skeletal"); os.makedirs(out, exist_ok=True)
        bpy.ops.export_scene.fbx(filepath=os.path.join(out, name + ".fbx"),
            use_selection=False, object_types={'ARMATURE','MESH'},
            add_leaf_bones=False, bake_anim=True,
            apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y')

    for pskx in glob.glob(os.path.join(pskx_dir, "*.pskx")):
        reset_scene()
        bpy.ops.import_scene.psk(filepath=pskx)                 # addon reads .pskx too
        name = os.path.splitext(os.path.basename(pskx))[0]
        out = os.path.join(out_dir, pkg, "static"); os.makedirs(out, exist_ok=True)
        bpy.ops.export_scene.fbx(filepath=os.path.join(out, name + ".fbx"),
            use_selection=False, object_types={'MESH'},
            add_leaf_bones=False, bake_anim=False,
            apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y')

def main():
    argv = sys.argv[sys.argv.index("--")+1:]
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="inp", required=True)
    p.add_argument("--out", required=True)
    a = p.parse_args(argv)
    for pkg_dir in sorted(glob.glob(os.path.join(a.inp, "*"))):
        if os.path.isdir(pkg_dir):
            try:    convert_package(pkg_dir, a.out); print("OK  ", os.path.basename(pkg_dir))
            except Exception as e: print("FAIL", os.path.basename(pkg_dir), e)

main()
```

Gotchas:
- **Runtime/size:** 761 skeletal + 2,415 static → run overnight; log OK/FAIL.
  FBX is bulkier than PSK — `converted/fbx` may reach ~10–15 GB (gitignored).
- **Animation explosion:** importing every PSA onto every mesh is wrong and huge.
  Refine after Phase A: only import PSAs whose bone hierarchy matches the mesh's
  armature; convert shared `*_Animset_SF` banks once against their canonical skeleton.
- **Operator params drift** between addon versions — confirm in Phase A (§4.3).

## 9. Phase C — Bulk import into UE5

- Textures: import `exported/textures/**/*.png` into `Content/IB3/Textures/`;
  mark `*_N` as Normal Map; disable sRGB on normal/spec/mask maps.
- Meshes/anims: UE5 Interchange bulk FBX import (or an Editor Python script over
  `converted/fbx`). Share a skeleton where bone hierarchies match so animations
  retarget cleanly. Mirror the package-name folder structure in Content.

## 10. Phase D — Materials (UE5, not Blender)

UE3 mobile material graphs don't port. Rebuild:
1. One master material `M_IB3_Master` (params: BaseColor, Normal, Specular
   Power/Mask, Environment/reflection amount).
2. Per `exported/materials/**/*.props.txt`, create a material instance:
   `MobileBaseTexture`→BaseColor, `MobileNormalTexture`→Normal,
   `MobileSpecularPower`/`MobileSpecularMask`/`MobileEnvironmentAmount`→spec/mask/reflection.
   The `.mat` stub summarizes Diffuse/Normal for a quick check.
3. Script with UE5 Editor Python (`tools/convert/build_materials.py`): parse
   `.props.txt`, create instance, assign textures, bind to mesh material slots.

## 11. Verification checklist

- [ ] Blender installed; `--version` confirmed; `io_scene_psk_psa` enabled.
- [ ] Phase A: one `BOSS_*` rig → UE5 with skeleton + skin + a playing animation.
- [ ] Static mesh (`IB3_Wp_*`) imports at correct scale/orientation.
- [ ] A rebuilt material instance shows correct diffuse + normal on its mesh.
- [ ] Batch log OK/FAIL ratio acceptable; FAILs triaged by package type.
- [ ] Scale consistent across assets (fix once in export or UE import scale).

## 12. Outputs (create these)

```
tools/convert/psk_to_fbx.py       # batch PSK/PSA → FBX        (commit)
tools/convert/build_materials.py  # UE5-side material rebuild  (commit)
converted/fbx/                    # generated FBX  (gitignored, ~10-15 GB)
```

## 13. Start here (next session)

1. Confirm the source data is present: `ls exported/geo | head` and
   `find exported/geo -name '*.psk' | wc -l` (expect 761).
2. **Install Blender** (§5.1) and verify `<BLENDER_BIN> --version`.
3. Install+enable `io_scene_psk_psa` headless (§4.2), then **probe operator
   params** (§4.3) and update the Phase B script signatures if needed.
4. **Do Phase A** on one `BOSS_*` asset, using headless import + render-to-PNG to
   verify orientation/scale (§4.4, §7). Lock in export constants.
5. Write/commit `tools/convert/psk_to_fbx.py`, run the **Phase B** batch (§8).
6. Then Phases C/D once a UE5 project exists (Phase 2 in `plan.md`).

Housekeeping still open from the previous session: `blender.md` and the
`.gitignore` update (adding `/converted/`) may be **uncommitted** — commit them.
The external-drive `rsync` may still be running; don't unplug mid-copy.
