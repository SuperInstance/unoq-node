# Uno Q node package — git-native bodies

Each Arduino Uno Q (Qualcomm Dragonwing QRB2210: Debian on A53, STM32U585
on Zephyr, Wi-Fi, Docker-capable) becomes a **body**: a physical place the
git agent commands. Git is the substrate — memory is commit history, the
queue is [agent-inbox](https://github.com/SuperInstance/agent-inbox),
state is the working tree, identity is the body id in commits. Kill any
application layer and the body persists: it IS the repos.

## Layout

- `onboard.sh` — the paste block for a fresh board (see below)
- `bin/tick.sh` — the heartbeat: pull inbox, filter for this body, claim via
  push, execute, deliver. Shell + git only, sized for A53/2GB.
- `bin/run-task.sh` — executes a claimed task (`deploy:` line or a ` ```run `
  fenced block)
- `bin/deploy.sh` — arduino-cli compile + upload to the STM32 + receipt
- `bodies/<id>/manifest` — body registration (shell-sourcable)
- `bodies/<id>/sketches/<name>/` — programs for this body; a deploy is a commit
- `bodies/<id>/uplink/<date>.log` — append-only daily sensor witness
- `docs/MANIFEST.md`, `docs/DEPLOY.md` — formats and flows

## Bringing up the first board (Casey's runbook)

1. Boot the Uno Q, ssh in (or attach console).
2. Run the paste block:
   ```
   sh <(curl -fsSL https://raw.githubusercontent.com/SuperInstance/unoq-node/main/onboard.sh) \
      --id q1 --location "lab-bench"
   ```
3. Add the printed public key as a **deploy key (read/write)** on
   SuperInstance/agent-inbox and SuperInstance/unoq-node.
4. Edit `bodies/q1/manifest` census (SENSORS/ACTUATORS/CAPABILITIES), push.
5. Watch: `journalctl --user -u unoq-tick.service -f` — tick every 2 min.
6. Smoke-test from anywhere: drop a task in agent-inbox:
   ```
   # inbox/010-blink-q1.md
   to: q1
   from: muse
   deploy: bodies/q1/sketches/blink
   ```
   Next tick: claims, compiles, uploads to the STM32, delivers a receipt to
   `done/010-blink-q1/result.md` with commit hashes. Rollback = redeploy an
   older sketch commit (`git revert`).

## Design rules

- **The push is the lock** — a claim exists when the push succeeds, never sooner.
- **Deployments are commits** — program state is revertible history.
- **Witness chain: voltage → commit hash** — daily append-only files, never
  rewritten, rotated out only by archive (never destroy).
- **No secrets in the repo** — the body key lives on the board only.
- **Light tick** — no Docker, no Python runtime, `sh` + `git` + `arduino-cli`.
