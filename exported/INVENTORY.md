# IB3 extraction — inventory

Source: `Infinity Blade III 1.4.4` iOS IPA → `SwordGame.app/CookedIPhone/`
(1,288 UE3 cooked packages, Engine build 13249). Extracted with UE Viewer
(umodel) via the pipeline in `tools/extract/`. See `tools/extract/README.md`.

## Contents

| Asset | Count | Location | Format |
|-------|------:|----------|--------|
| Skeletal meshes | 761 | `geo/<pkg>/SkeletalMesh3/*.psk` | Unreal PSK (+ `.props.txt`) |
| Static meshes | 2,415 | `geo/<pkg>/StaticMesh3/*.pskx` | Unreal PSKX (+ `.props.txt`) |
| Animation sets | 690 | `geo/<pkg>/AnimSet/*.psa` | Unreal PSA |
| Textures | 7,495 | `textures/<pkg>/Texture2D/*.png` | PNG, downscaled to ≤1024px |
| Materials | 2,891 | `materials/<pkg>/.../*.mat` + `.props.txt` | texture map + mobile params |

Total: **7.4 GB** (geo 1.6 GB, textures 5.7 GB, materials 33 MB).

## Notes for the UE5 import stage

- **Meshes/anims** are native Unreal PSK/PSA — import into Blender with the
  `io_scene_psk_psa` addon, then export glTF/FBX for UE5. `.psa` files hold the
  animation curves; retarget onto the imported skeletons.
- **Textures** were decoded from the iOS `.tfc` caches (required umodel's `-ios`
  flag). Full-res was 2048px for hero assets; capped at 1024 here to fit disk —
  re-run `run_textures.sh` with `MAXDIM=2048` for any specific hero asset if needed.
- **Materials** don't port as graphs (UE3 mobile → UE5). Rebuild them from the
  `.props.txt`, which give the wiring, e.g.:
  `MobileBaseTexture` → diffuse, `MobileNormalTexture` → normal,
  `MobileSpecularPower` / `MobileEnvironmentAmount` / `MobileSpecularMask` →
  spec/reflection params. The `.mat` stub summarizes Diffuse/Normal per material.
- Package name prefixes map to content: `BOSS_*` enemies, `B_*`/`SA_*` weapons &
  gear, `A00_*`..`L0x_*` arenas/locales, `*_Animset_SF` shared animation banks,
  `CFX_*` cinematic/FX. Many `IB1_`/`IB2_`-prefixed assets are shared legacy content.

Loose bundle audio (142 MP3s, 6 M4V cutscenes) remains in
`extracted/Payload/SwordGame.app/CookedIPhone/` — copy directly, no decode needed.
