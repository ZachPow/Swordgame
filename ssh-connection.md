# SSH + LAN asset transfer — connection handoff

**Purpose:** everything needed to pull the ~6.5 GB `exported/` assets from the
**Mac** to the **Windows PC** over the LAN via SSH. This captures a working
setup mid-transfer so a fresh session/person can finish it without re-deriving
the whole thing. Companion to `pc-setup.md` (broader PC bring-up) and
`blender.md` (what happens after the assets land).

---

## TL;DR — the command that should work

On the PC (WSL/Ubuntu terminal):
```bash
mkdir -p /mnt/c/ib3/exported

rsync -rt --progress \
  --no-perms --no-owner --no-group \
  --rsync-path=/opt/homebrew/bin/rsync \
  -e "ssh -i ~/.ssh/id_ed25519_ib3mac" \
  zacharypower@192.168.1.124:/Users/zacharypower/ib3-assets/exported/ \
  /mnt/c/ib3/exported/
```
Then verify: `find /mnt/c/ib3/exported -type f | wc -l` → expect **26964**.

Why these exact flags, and every gotcha behind them, below.

## Verified facts (as of 2026-07-23)

- **Mac (source):** user `zacharypower`, IP **`192.168.1.124`** (DHCP — can
  change; see Troubleshooting), hostname `Zacharys-MacBook-Air-2.local` (usually
  NOT resolvable from WSL2 → use the IP). `sshd` (Remote Login) is ON.
- **SSH key auth is set up and working.** The PC generated an ed25519 key
  `id_ed25519_ib3mac`; its public key is installed in the Mac's
  `~/.ssh/authorized_keys` (comment `zach-pc-to-mac-ib3`). Password auth is no
  longer needed. The key has a **non-default name**, so every command must pass
  `-i ~/.ssh/id_ed25519_ib3mac` (rsync via `-e "ssh -i ~/.ssh/id_ed25519_ib3mac"`).
- **GNU rsync 3.4.4** is installed on the Mac at **`/opt/homebrew/bin/rsync`**
  (Homebrew). Always pass `--rsync-path=/opt/homebrew/bin/rsync` — macOS's
  default `openrsync` is flaky and an SSH login shell won't have Homebrew on PATH.
- **Assets (source):** **`/Users/zacharypower/ib3-assets/exported/`** —
  `geo/`, `textures/`, `materials/`, **26,964 files, ~6.5 GB**. (`INVENTORY.md`
  is NOT here; it's tracked in git and arrives via the repo clone.)
- **Destination (PC):** `C:\ib3\exported` → `/mnt/c/ib3/exported/` in WSL.

## Two things that caused most of the pain

### 1. "Operation not permitted" — has TWO different causes
Same message, different sides:
- **Mac side (TCC):** macOS blocks SSH sessions from reading `~/Desktop`,
  `~/Documents`, `~/Downloads` — even as the owner. The project lives under
  `~/Desktop`, so reading `.../Desktop/dev/InfinityBlade/exported` over SSH fails.
  **Fix chosen:** the asset data was **moved out of `~/Desktop`** to
  `/Users/zacharypower/ib3-assets/exported/` (a TCC-safe location). **Leave it
  there** for the transfer. (The alternative — granting `/usr/sbin/sshd` Full
  Disk Access in System Settings — kept silently failing to "stick"; even
  `/usr/libexec/sshd-keygen-wrapper` didn't take. Not worth fighting.)
- **PC side (DrvFs):** `rsync -a` tries to set Unix owner/permissions on the
  Windows `C:` drive, which NTFS rejects with the identical "Operation not
  permitted." **Fix:** use `-rt` instead of `-a`, plus
  `--no-perms --no-owner --no-group`. This is why the TL;DR command drops `-a`.

If "Operation not permitted" still appears, read WHICH path the error names to
tell the two apart — a Mac path = TCC (source), a `chown`/`chmod`/`/mnt/c` mention
= DrvFs (destination). Note DrvFs perm messages are often **non-fatal warnings**;
the file data may copy anyway (rsync exits 23 "partial transfer due to errors").

### 2. The USB drive is dead-end — use the LAN
The first attempt copied `exported/` to a FAT32 USB stick, then robocopy on the
PC **failed on 191 files with `ERROR 1392` ("corrupted and unreadable")** — the
card mangled them on write, and silent corruption of others is likely. The Mac
holds pristine originals, so **ignore the USB stick and any
`ib3_missing_191.zip`** and pull fresh over the network (LAN read from the good
Mac disk is correct by definition).

## Full procedure (from scratch on the PC)

1. **WSL + rsync:** in an Admin PowerShell `wsl --install` (reboot, make an
   Ubuntu user). In Ubuntu: `rsync --version` (if missing:
   `sudo apt update && sudo apt install -y rsync`).
2. **SSH key** (only if not already done — it IS done as of this writing):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_ib3mac -C zach-pc-to-mac-ib3   # no passphrase
   ssh-copy-id -i ~/.ssh/id_ed25519_ib3mac.pub zacharypower@192.168.1.124     # enter Mac login password once
   ```
3. **Sanity test the connection + read access:**
   ```bash
   ssh -i ~/.ssh/id_ed25519_ib3mac zacharypower@192.168.1.124 \
     "ls /Users/zacharypower/ib3-assets/exported"
   ```
   Must print `geo  materials  textures` with no "Operation not permitted."
4. **Pull** — run the TL;DR command.
5. **Verify** — `find /mnt/c/ib3/exported -type f | wc -l` → **26964**;
   `du -sh /mnt/c/ib3/exported` → ~6.5 G.
6. **Repo:** clone `https://github.com/ZachPow/Swordgame.git` (e.g. to `C:\ib3`)
   for the code/docs; it also provides `exported/INVENTORY.md`. Keep the pulled
   `exported/` data alongside it — `.gitignore` keeps it untracked.

## Troubleshooting

- **Connection times out:** the Mac's DHCP IP changed. Get the new one on the Mac
  with `ipconfig getifaddr en0` and substitute it. (A router DHCP reservation
  makes it permanent.)
- **Asks for a password:** the `-i ~/.ssh/id_ed25519_ib3mac` is missing/wrong, or
  key perms are off. Confirm on the Mac: `grep -c . ~/.ssh/authorized_keys` ≥ 1.
  Password itself is the Mac **login** password (verified valid via
  `dscl . -authonly zacharypower`).
- **"Operation not permitted":** see the two-causes section above.
- **`rsync: command not found` on the Mac side:** the `--rsync-path` value is
  wrong; confirm `ls -l /opt/homebrew/bin/rsync` on the Mac.
- **Interrupted transfer:** just re-run the same rsync — it resumes, only sending
  what's missing.

## After the transfer

Assets are extracted but not yet UE5-ready. Continue with **`blender.md`**
(PSK/PSA → FBX conversion; also covers installing Blender, which is not installed
on either machine). Roadmap is in `plan.md`.

## Current status at handoff

SSH key auth works; assets staged at the TCC-safe
`/Users/zacharypower/ib3-assets/exported/`. Last blocker was "Operation not
permitted" persisting after moving the data — attributed to the PC-side DrvFs
permission issue; the fix (drop `-a`, use `-rt --no-perms --no-owner --no-group`)
is baked into the TL;DR command but had not yet been confirmed working when this
was written. **Next action:** run the TL;DR command and confirm the file count
hits 26964.
