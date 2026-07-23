# PC setup & asset transfer — handoff

**Purpose:** stand up the second dev machine (a **Windows PC**) for the Infinity
Blade III UE5 remake — clone the repo and pull the ~6.5 GB of extracted assets
reliably from the Mac over the LAN. Written so a fresh session/person can follow
it start to finish. When done, continue with `blender.md`.

---

## 0. Background (why LAN, not the USB stick)

The assets were first copied to a FAT32 USB stick, but that card is unreliable —
a robocopy run **failed on 191 files with `ERROR 1392` ("corrupted and
unreadable")** reading from the stick, and silent corruption of other files is
possible on media like that. The Mac holds the pristine originals, and both
machines are on the same network, so the correct approach is a **direct
LAN transfer with checksum verification** (rsync over SSH). Ignore the USB stick
and any `ib3_missing_191.zip` — this method supersedes them.

## 1. What lives where

- **Git repo (code, docs, tools — small):**
  `https://github.com/ZachPow/Swordgame.git`
- **Assets (NOT in git, transferred separately):** `exported/` — **26,970 files,
  ~6.5 GB** (761 skeletal `.psk`, 2,415 static `.pskx`, 690 `.psa`, 7,495 PNG
  textures, 2,891 materials). `.gitignore` keeps this untracked; it must be
  copied into the repo folder manually after cloning.
- **Mac source machine (verified this session):**
  - user `zacharypower`, source path
    `/Users/zacharypower/Desktop/dev/InfinityBlade/exported/`
  - LAN IP **`192.168.1.124`** (DHCP — may change; see Troubleshooting)
  - hostname `Zacharys-MacBook-Air-2.local` (often not resolvable from WSL2 — use the IP)
  - SSH (Remote Login) is ON; GNU **rsync 3.4.4** installed at
    `/opt/homebrew/bin/rsync`

## 2. Prerequisites on the PC

- **Git** — https://git-scm.com/download/win (or `winget install Git.Git`)
- **WSL** (gives you `rsync`/`ssh`) — see Step 3. Alternatively use the no-WSL
  SMB fallback in the appendix.
- Disk: **≥ 20 GB free** (6.5 GB assets now; FBX conversion output later adds
  ~10–15 GB per `blender.md`).

## 3. Install WSL (skip if already installed)

In an **Administrator PowerShell**:
```powershell
wsl --install
```
Reboot if prompted, then launch **Ubuntu** from the Start menu and create a
username/password. Confirm rsync is present:
```bash
rsync --version    # if missing: sudo apt update && sudo apt install -y rsync
```

## 4. Clone the repo

Pick a **short path** to avoid Windows' 260-char path limit (deeply nested
asset paths were part of the earlier copy trouble). In WSL:
```bash
cd /mnt/c
git clone https://github.com/ZachPow/Swordgame.git ib3
cd ib3
```
This gives you `C:\ib3\` containing `plan.md`, `blender.md`, `pc-setup.md`,
`tools/`, `.gitignore`, and `exported/INVENTORY.md` — but **not** the assets yet.

## 5. Pull the assets over the LAN (the important step)

Make sure the **Mac is awake** and on the same network. Then from WSL:

```bash
rsync -av --checksum --progress \
  --rsync-path=/opt/homebrew/bin/rsync \
  zacharypower@192.168.1.124:/Users/zacharypower/Desktop/dev/InfinityBlade/exported/ \
  /mnt/c/ib3/exported/
```

What each part does:
- `--rsync-path=/opt/homebrew/bin/rsync` — forces the Mac to use **GNU rsync**
  (installed there), not macOS's `openrsync`, which is flaky with `--checksum`.
- `--checksum` — hashes every file on both ends, so it **re-sends the 191 corrupt
  files and overwrites any silently-corrupted ones**, while leaving good files
  untouched. Slower (it reads all 6.5 GB to hash) but it *proves* correctness.
- Trailing slash on the **source** `exported/` matters — it copies the contents
  into the destination `exported/` (no doubled `exported/exported`).
- First connect: accept the host key (`yes`), then enter the Mac password.

**Faster first pass (optional):** drop `--checksum` to compare by size+timestamp
— quick, fixes the 191 missing/failed files, but won't catch silent corruption.
Run the full `--checksum` version at least once given the bad-card history.

If it exits with `sent … received … total size` and no error lines, the transfer
is complete and verified.

## 6. Verify

```bash
find /mnt/c/ib3/exported -type f | wc -l      # expect 26970
du -sh /mnt/c/ib3/exported                    # expect ~6.5G
```
26,970 files ≈ done. (A second `rsync … --checksum` run that says nothing was
transferred is the definitive "byte-perfect" confirmation.)

`.gitignore` already lists `/exported/`, so `git status` should stay clean — the
assets live alongside the repo without being tracked.

## 7. What's next

The assets are extracted but **not yet UE5-ready** (PSK/PSA meshes/anims need
conversion; textures import as-is; materials get rebuilt in UE5). Follow
**`blender.md`** — it's the full runbook for that, and it also covers installing
Blender (note: Blender is **not** installed on the Mac, and won't be on the PC
either — install it fresh per that doc). Broader roadmap is in `plan.md`.

---

## Appendix — no-WSL fallback (SMB + robocopy)

If you can't/don't want WSL:
1. **Mac:** System Settings → General → Sharing → **File Sharing** ON → add the
   `InfinityBlade` folder.
2. **PC:** open `\\192.168.1.124` in Explorer, sign in as `zacharypower`, then in
   a normal terminal (short destination to dodge the path limit):
   ```
   robocopy \\192.168.1.124\InfinityBlade\exported C:\ib3\exported /E /R:2 /W:2 /Z /IS
   ```
   `/IS` re-copies same-size files too, overwriting anything silently corrupted
   from the bad card. Reading from the Mac's good disk is the reliable part;
   robocopy doesn't checksum, so prefer the rsync method when possible.

## Troubleshooting

- **Connection times out / wrong IP:** DHCP changed the Mac's address. On the Mac
  run `ipconfig getifaddr en0` for the current IP and substitute it. (A router
  DHCP reservation makes it permanent.)
- **`rsync: command not found` on the Mac side:** re-check the `--rsync-path`
  value; confirm on the Mac with `ls -l /opt/homebrew/bin/rsync`.
- **Permission denied (publickey/password):** ensure Remote Login is still ON
  (System Settings → General → Sharing) and you're using the Mac login password.
- **Slow `--checksum`:** expected — it hashes 6.5 GB on both ends. Let it run, or
  do the fast size/mtime pass first, then a `--checksum` pass to verify.
- **Windows path-length errors:** keep the destination short (`C:\ib3\`), and in
  WSL you're immune anyway.
