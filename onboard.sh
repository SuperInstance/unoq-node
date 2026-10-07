#!/bin/sh
# onboard.sh — turn a fresh Uno Q (QRB2210, Debian) into a git-native body.
# Paste block: sh <(curl -fsSL <repo-raw>/onboard.sh) --id q1 --location "dock"
# (or run locally after cloning unoq-node)
set -eu

ID=""
LOCATION=""
INBOX_URL="https://github.com/SuperInstance/agent-inbox"
NODE_REPO="https://github.com/SuperInstance/unoq-node"

while [ $# -gt 0 ]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
    --inbox-url) INBOX_URL="$2"; shift 2 ;;
    *) echo "unknown arg $1"; exit 1 ;;
  esac
done
[ -n "$ID" ] || { echo "usage: onboard.sh --id <body-id> --location <where> [--inbox-url URL]"; exit 1; }
[ -n "$LOCATION" ] || { echo "--location required (the agent commands PLACES, not boards)"; exit 1; }

echo "== [1/6] base packages"
sudo apt-get update -qq && sudo apt-get install -y -qq git jq curl cron

echo "== [2/6] arduino-cli"
if ! command -v arduino-cli >/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=/usr/local/bin sh
  arduino-cli core update-index
  arduino-cli core install "STMicroelectronics:stm32" || echo "WARN: stm32 core install failed — run manually later"
fi

echo "== [3/6] body keypair (no passphrase; key never enters any repo)"
ssh-keygen -q -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" 2>/dev/null || true
echo "-- add this public key to the SuperInstance deploy keys (read/write):"
cat "$HOME/.ssh/id_ed25519.pub"

echo "== [4/6] clone the substrate"
mkdir -p "$HOME/git" && cd "$HOME/git"
[ -d agent-inbox ] || git clone "$INBOX_URL" agent-inbox
[ -d unoq-node ]   || git clone "$NODE_REPO" unoq-node

echo "== [5/6] register the body manifest"
cd unoq-node
BODY_DIR="bodies/$ID"
if [ ! -d "$BODY_DIR" ]; then
  cp -r bodies/_TEMPLATE "$BODY_DIR"
  sed -i "s/^BODY_ID=.*/BODY_ID=$ID/" "$BODY_DIR/manifest"
  sed -i "s|^LOCATION=.*|LOCATION=$LOCATION|" "$BODY_DIR/manifest"
  # sensor/capability census — edit by hand after onboarding
  git add "$BODY_DIR" && git commit -m "onboard: body $ID at $LOCATION" && git push
fi

echo "== [6/6] install the tick (systemd + timer, light: shell + git only)"
echo "$ID" > BODY   # body identity file the tick reads
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/unoq-tick.service <<EOF
[Unit]
Description=Uno Q git-native body tick

[Service]
Type=oneshot
ExecStart=$HOME/git/unoq-node/bin/tick.sh
Environment=HOME=$HOME
EOF
cat > ~/.config/systemd/user/unoq-tick.timer <<EOF
[Unit]
Description=Run body tick every 2 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now unoq-tick.timer

echo
echo "ONBOARDED: $ID at $LOCATION. Next: edit bodies/$ID/manifest census, then push."
echo "Tick logs: journalctl --user -u unoq-tick.service -f"
