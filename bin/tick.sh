#!/bin/sh
# tick.sh — the body's heartbeat. Light: sh + git only (A53 / 2GB friendly).
# Pull inbox -> filter tasks for THIS body (to: <id> | to: any w/ needs match)
# -> claim (push is the lock) -> execute -> commit result -> push.
# Witness: append-only daily sensor log committed to unoq-node.
set -u
HOME="${HOME:-/root}"
export HOME
NODE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INBOX="$HOME/git/agent-inbox"
LOG="$NODE_DIR/tick.log"
BODYFILE="$NODE_DIR/BODY"

log() { echo "$(date -u +%FT%TZ) $*" >> "$LOG"; tail -n 200 "$LOG" > "$LOG.t" && mv "$LOG.t" "$LOG"; }

[ -f "$BODYFILE" ] || { log "FATAL: $BODYFILE missing (run onboard.sh)"; exit 1; }
ID="$(cat "$BODYFILE")"
MANIFEST="$NODE_DIR/bodies/$ID/manifest"
[ -f "$MANIFEST" ] || { log "FATAL manifest missing for $ID"; exit 1; }
. "$MANIFEST"
CAPS="$CAPABILITIES"

cd "$INBOX" || { log "FATAL no inbox clone"; exit 1; }
git pull --quiet || { log "pull failed (offline?)"; exit 0; }

for task in inbox/*.md; do
  [ -e "$task" ] || continue
  # addressing filter: to: <this body> or to: any
  TO=$(grep -m1 '^to:' "$task" | sed 's/^to:[[:space:]]*//')
  [ "$TO" = "$ID" ] || [ "$TO" = "any" ] || continue
  # needs filter (task front-matter may declare needs: a,b)
  NEEDS=$(grep -m1 '^needs:' "$task" | sed 's/^needs:[[:space:]]*//')
  if [ -n "$NEEDS" ]; then
    ok=1
    OLDIFS="$IFS"; IFS=','
    for n in $NEEDS; do
      case ",$CAPS," in *",$n,"*) ;; *) ok=0 ;; esac
    done
    IFS="$OLDIFS"
    [ $ok -eq 1 ] || continue
  fi

  base=$(basename "$task" .md)
  log "claiming $base"
  mkdir -p "claimed/$ID"
  git mv "$task" "claimed/$ID/$(basename "$task")" || continue
  if ! (git commit -q -m "claim: $base by $ID" && git push -q); then
    git reset -q --hard; git pull --rebase -q; log "lost race on $base"; continue
  fi

  sh "$NODE_DIR/bin/run-task.sh" "$base" "claimed/$ID/$base.md" "$ID" \
    && log "done $base" || log "run-task nonzero for $base (task runner books it)"
  git push -q || { git pull --rebase -q && git push -q; }
done

# witness: append-only daily uplink in the NODE repo (voltage -> commit hash)
[ "${WITNESS:-1}" = "1" ] && {
  cd "$NODE_DIR"
  W="bodies/$ID/uplink/$(date -u +%F).log"
  mkdir -p "$(dirname "$W")"
  { date -u +%FT%TZ; uptime; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null; } >> "$W"
  git add "$W" 2>/dev/null
  git commit -q -m "witness: $ID $(date -u +%F)" 2>/dev/null && git push -q
}
exit 0
