#!/bin/sh
# run-task.sh — execute a claimed task for this body.
# Task kinds, tried in order:
#   1. sketch deploy: task body contains "deploy: bodies/<id>/sketches/<name>"
#   2. generic: each ```run fenced block executed with sh (FIRST match only —
#      tasks are trusted from the fleet, but blocks are visible before run)
# Result committed to done/<task>/result.md by the caller's push.
set -u
BASE="$1"; TASKFILE="$2"; ID="$3"
INBOX="$(cd "$(dirname "$0")/../../agent-inbox" 2>/dev/null && pwd)"
[ -z "$INBOX" ] && INBOX="$HOME/git/agent-inbox"
NODE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DONE="$INBOX/done/$BASE"
mkdir -p "$DONE"

SKETCH=$(grep -m1 '^deploy:' "$TASKFILE" | sed 's/^deploy:[[:space:]]*//')
if [ -n "$SKETCH" ]; then
  sh "$NODE_DIR/bin/deploy.sh" "$SKETCH" "$DONE/result.md" && \
  git -C "$INBOX" mv "claimed/$ID/$(basename "$TASKFILE")" "$DONE/task.md" && \
  git -C "$INBOX" add "$DONE" && git -C "$INBOX" commit -q -m "done: $BASE by $ID"
  exit $?
fi

# generic fenced run block
BLOCK=$(awk '/^```run/{f=1;next} /^```/{f=0} f' "$TASKFILE" | head -50)
if [ -n "$BLOCK" ]; then
  {
    echo "**DONE**"; echo; echo '```'; echo "$BLOCK" | sh 2>&1; echo '```'
  } > "$DONE/result.md"
  git -C "$INBOX" mv "claimed/$ID/$(basename "$TASKFILE")" "$DONE/task.md"
  git -C "$INBOX" add "$DONE" && git -C "$INBOX" commit -q -m "done: $BASE by $ID"
  exit $?
fi

echo "**BLOCKED** — no deploy: line and no \`\`\`run block; body $ID can only run those." > "$DONE/result.md"
git -C "$INBOX" mv "claimed/$ID/$(basename "$TASKFILE")" "$DONE/task.md"
git -C "$INBOX" add "$DONE" && git -C "$INBOX" commit -q -m "blocked: $BASE by $ID"
exit 0
