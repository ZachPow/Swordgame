# Infinity Blade III — UE5 Remake

## Context

Infinity Blade III (ChAIR/Epic, 2013, iOS-only, UE3) was delisted in 2018 and removed from the App Store in 2020. Fan PC ports exist for IB1 and IB2 (built from the 2014 UE3 source leak + IPA content), but IB3 shipped on a newer, more customized UE3 build, so that method doesn't transfer cleanly and no IB3 port exists.

Chosen approach: **rebuild IB3 in Unreal Engine 5**, using assets and game data extracted from the user's own copy of the game (installed on an iOS device they own), supplemented by Epic's officially free Infinity Blade asset packs on Fab. All gameplay code is written fresh — nothing depends on leaked engine source.

Scope posture: personal, non-commercial preservation project. Extracted assets stay private; only clean code and Fab assets could ever be shared.

This repo (`/Users/zacharypower/Desktop/dev/InfinityBlade`) is empty — everything below is greenfield.

## Phase 0 — Obtain the game files

Goal: a copy of the IB3 `.app` bundle on the Mac.

Key fact: only the executable is FairPlay-encrypted. The game content — cooked UE3 packages (`.xxx`), audio, movies — is **unencrypted** inside the bundle, and the executable isn't needed for asset extraction.

**Decided route: archived IPA.** The user's device is an iPhone 16 (A18, iOS 18), for which no jailbreak or TrollStore exists, so on-device filesystem dumping is not possible. Instead use the preserved IB3 IPA (v1.4.4 on the Internet Archive), which contains the identical unencrypted `CookedIPhone/` content — device dumping would have produced the same files. Legitimacy rests on owning the game, which the user does.

Steps:
1. Download the IB3 v1.4.4 IPA from the Internet Archive.
2. An IPA is a ZIP — unzip it: `unzip InfinityBlade3.ipa -d extracted/`.
3. The bundle is at `extracted/Payload/InfinityBlade3.app/`; confirm `CookedIPhone/` full of `.xxx` files is present.

Deliverable: `extracted/…/InfinityBlade3.app/` (git-ignored) containing `CookedIPhone/` packages.

## Phase 1 — Asset & data extraction pipeline  ✅ DONE

**Status (complete):** All 1,288 cooked packages extracted via `tools/extract/`
(umodel in an i386 container under Colima+Rosetta). Output in `exported/` — 761
skeletal meshes, 2,415 static meshes, 690 animation sets, 7,495 textures (PNG
≤1024), 2,891 materials. ~7.4 GB. See `exported/INVENTORY.md` and
`tools/extract/README.md`. Remaining Phase-1 work: convert PSK/PSA → glTF/FBX in
Blender for UE5 import; mine UnrealScript for game-data tables (items/enemies/gems).

Tools (macOS / Apple Silicon note — dev machine is an M2, macOS 26):
- **UE Viewer (UModel)** — reads Infinity Blade packages (explicit support for the IB series). Export: skeletal/static meshes → glTF/FBX (mesh, skeleton, skin weights), animations → psa/glTF, textures → PNG/TGA.
  - There is **no native GUI macOS build**. Two workable setups:
    1. **Primary — Gildor's macOS CLI build** (x86, runs on M2 via Rosetta 2). No 3D viewer / no multithreading; functions as a headless batch exporter. Sufficient for bulk export via `umodel -export -path=<CookedIPhone> -out=<dir> -gltf ...`. This is what `tools/extract/` scripts target.
    2. **Optional — Windows UModel under CrossOver** (Wine 11 / D3DMetal, supports Apple Silicon) when the visual asset browser is wanted to identify/preview packages before export. Whisky is discontinued (April 2025) — do not use.
- **UE Explorer** or `unrealscript` decompilers on the script packages (`IB3Game.xxx`, etc.) — not to reuse code, but to **read** class properties: item stats, gem/forge rules, enemy attack sets, prize tables, store data. Much IB3 tuning data lives in UnrealScript `defaultproperties` and cooked archetypes.
- Audio: packages contain OGG/ADPCM SoundNodeWaves; UModel exports these. Music may be standalone files in the bundle.

Repo layout:
```
tools/extract/        # scripts wrapping umodel batch export
extracted/            # git-ignored raw exports
docs/data/            # mined game data as JSON/CSV (items, enemies, gems) — this IS committed
```

Deliverables: batch export scripts; an inventory doc (`docs/extraction-notes.md`) of what exported cleanly vs. what needs manual work (UE3→UE5 material graphs do not transfer — materials must be rebuilt from exported textures).

## Phase 2 — UE5 project scaffold

- UE 5.4+ C++ project `IB3Remake` at repo root; Git LFS for `Content/` binaries; standard UE `.gitignore`.
- Pull Epic's free Infinity Blade packs from Fab (**Grass Lands, Ice Lands, Fire Lands, Warriors, Adversaries, Weapons, Effects, Sounds**) — legal supplementary/placeholder content that matches the art style.
- Enhanced Input, GameplayTags; consider GAS (Gameplay Ability System) for combat abilities — attacks/parries/magic map naturally onto abilities + tags.

## Phase 3 — Combat vertical slice (the heart of the game)

One arena, one enemy (use a Fab "Adversary" first, extracted IB3 enemy second). The IB duel loop:

- **Camera/framing:** fixed cinematic camera per battle node; player locked in place facing enemy.
- **Player verbs:** slash (mouse swipe direction / right-stick flick), **parry** (swipe matching incoming attack vector inside timing window), **dodge left/right**, **block** (shield, durability), **magic** (draw sigil / cast hotkey), super attack meter.
- **Enemy side:** data-driven attack patterns — montage + attack vector + parry window + telegraph; combo chains; break/stab states on successful parry chains.
- **Feedback:** hit sparks, slow-mo on perfect parry, damage numbers — Fab Effects pack covers most VFX.

Implementation: `DuelGameMode`, `DuelCamera`, `PlayerDuelist` + `EnemyDuelist` pawns, `AttackPattern` data assets authored from mined enemy data. Input abstraction so touch-style swipes map to mouse drags and gamepad.

Milestone: a winnable, losable duel that *feels* like Infinity Blade. Everything after this is content and systems.

## Phase 4 — Progression & meta systems

- Items (weapons/shields/armor/helms/rings), stats, XP-mastery per item — schema from Phase 1 mined data (`docs/data/items.json`).
- Gems + forge, potions, gold/chips economy, store.
- **Bloodline/rebirth loop** and map-node navigation between battles (the on-rails "choose path, walk, fight" structure).
- SaveGame subsystem (replaces the dead cloud saves).

## Phase 5 — World & content build-out

- Recreate IB3 locales; three sources per map, in preference order: extracted static meshes from the actual IB3 maps, Fab pack environments (Grass/Ice/Fire Lands are literally IB environments), new-but-matching assets.
- The Hideout hub (crafting, potions, characters), dual protagonists (Siris/Isa) if extraction of both rigs succeeds.
- Story content (dialog, cutscene movies are in the bundle as video files) — stretch goal.

## Phase 6 — PC polish

Keybind remapping UI, graphics settings, ultrawide, gamepad glyphs, Steam Deck-friendly defaults.

## Verification

- **Phase 1:** open exported FBX/glTF in Blender — mesh, skeleton, and at least one animation intact; spot-check mined item data against in-game values on the device.
- **Phase 3 onward:** playable-in-editor at every step (`uecc` build + PIE); each phase ends with a tagged playable build. Combat feel is validated by side-by-side comparison with the game running on the actual device.
- CI-light: a `Build.sh` that compiles the C++ target headlessly to catch breakage.

## Legal guardrails

- Extracted IB3 assets and the `.app` never get committed or distributed (enforced via `.gitignore` + LFS rules).
- Fab pack assets are used within Epic's content license (Unreal-engine projects only).
- Project stays non-commercial; if it's ever shared, share code + Fab content only.
