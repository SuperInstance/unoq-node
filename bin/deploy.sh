#!/bin/sh
# deploy.sh — compile + upload a sketch to the STM32U585, write a receipt.
# usage: deploy.sh bodies/<id>/sketches/<name> <receipt-out-file>
set -u
SKETCH_REF="$1"; RECEIPT="$2"
NODE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKETCH_DIR="$NODE_DIR/$SKETCH_REF"
FQBN="${ARDUINO_FQBN:-STMicroelectronics:stm32:GenG0}"   # adjust per board variant
PORT="${ARDUINO_PORT:-/dev/ttyACM0}"

{
  echo "**DONE** — sketch deploy"
  echo
  echo "- sketch: \`$SKETCH_REF\`"
  echo "- started: $(date -u +%FT%TZ)"
} > "$RECEIPT"

if [ ! -d "$SKETCH_DIR" ]; then
  echo "- BLOCKED: sketch dir not found after pull: $SKETCH_DIR" >> "$RECEIPT"
  exit 1
fi

# lock: previous deployment hash, for rollback reference
PREV=$(git -C "$NODE_DIR" log -1 --format=%H -- "$SKETCH_REF" 2>/dev/null || echo none)

arduino-cli compile --fqbn "$FQBN" "$SKETCH_DIR" >> "$RECEIPT" 2>&1 || {
  echo "- BLOCKED: compile failed (see log above)" >> "$RECEIPT"; exit 1; }
arduino-cli upload -p "$PORT" --fqbn "$FQBN" "$SKETCH_DIR" >> "$RECEIPT" 2>&1 || {
  echo "- BLOCKED: upload failed (board on $PORT?)" >> "$RECEIPT"; exit 1; }

cat >> "$RECEIPT" <<EOF
- deployed: $(date -u +%FT%TZ)
- sketch_commit: $(git -C "$NODE_DIR" log -1 --format=%H -- "$SKETCH_REF")
- previous_deploy_commit: $PREV
- rollback: git revert <deploy commit> in unoq-node, or redeploy at $PREV
EOF

# deployment receipt into the node repo = the program IS a commit
git -C "$NODE_DIR" add -A "$SKETCH_REF" 2>/dev/null
git -C "$NODE_DIR" commit -q -m "deploy: $SKETCH_REF from task receipt" || true
exit 0
