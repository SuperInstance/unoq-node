# Sketch deploy flow — "copy a program in" as a commit

1. **Author** a sketch in `bodies/<id>/sketches/<name>/<name>.ino` (in the
   unoq-node repo), commit, push.
2. **Drop the order** into agent-inbox: a task file with `to: <id>` and a
   `deploy: bodies/<id>/sketches/<name>` line.
3. **Tick picks it up** (≤ TICK_SECONDS later): claims by push, then
   `bin/deploy.sh` runs:
   - `arduino-cli compile --fqbn $FQBN` (receipt captures the log)
   - `arduino-cli upload -p $PORT` to the STM32U585
   - receipt written to `done/<task>/result.md` with: sketch commit hash,
     previous deploy commit, timestamp, rollback instructions
4. **Rollback** = redeploy an older commit: `git revert <deploy commit>` in
   unoq-node (or check out the previous sketch commit) and drop a fresh
   deploy task. The program state of every body is a line of history.

Board notes: set `ARDUINO_FQBN` and `ARDUINO_PORT` in the body's
`~/.config/systemd/user/unoq-tick.service` Environment= lines when the
board variant/port is confirmed. Receipts are first-class: a deploy
without a receipt didn't happen (same law as experiment pre-regs).

## Sensor uplink

`tick.sh` appends one witness block per day to
`bodies-witness/<id>/<YYYY-MM-DD>.log` (timestamp, uptime, thermals) and
commits. Rules: append-only per day; never rewrite; archive (rename to
`*.archived-YYYYMMDD`) rather than delete when pruning; anything
high-rate goes to a local spool (ext4, NOT /tmp) and only daily
summaries ride the repo — same law as the laptop fleet: the repo is the
ledger, not the payload.
