#!/usr/bin/env bash
#
# bootstrap_vps.sh — provision a fresh Ubuntu VPS to run the YT Strategy Agent.
#
# Usage:
#   ./scripts/bootstrap_vps.sh <ip> <root-password>
#
# Run from the repo root on your laptop, AFTER the local smoke test passed.
# Requires sshpass (brew install hudochenkov/sshpass/sshpass).

set -euo pipefail

IP="${1:-}"
PW="${2:-}"

if [[ -z "$IP" || -z "$PW" ]]; then
  echo "usage: $0 <ip> <root-password>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="root@${IP}"
REMOTE_DIR="/root/yt-strategy-agent"

if ! command -v sshpass >/dev/null 2>&1; then
  echo "sshpass not found. Install with: brew install hudochenkov/sshpass/sshpass" >&2
  exit 1
fi

ssh_opts=(-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
ssh_run()   { sshpass -p "$PW" ssh   "${ssh_opts[@]}" "$REMOTE" "$@"; }
scp_to()    { sshpass -p "$PW" scp   "${ssh_opts[@]}" "$1" "$REMOTE:$2"; }

echo "→ Waiting for SSH on $IP..."
for _ in $(seq 1 60); do
  if ssh_run "true" 2>/dev/null; then break; fi
  sleep 2
done

echo "→ Installing Python, git, and tooling..."
ssh_run "DEBIAN_FRONTEND=noninteractive apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3.11 python3.11-venv python3-pip git ca-certificates"

echo "→ Cloning repo to $REMOTE_DIR..."
ssh_run "rm -rf $REMOTE_DIR && \
  git clone https://github.com/jackson-video-resources/yt-strategy-agent $REMOTE_DIR"

echo "→ Copying secrets and config..."
for f in .env client_secret.json token.pickle channels.yaml; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    scp_to "$REPO_ROOT/$f" "$REMOTE_DIR/$f"
  else
    echo "  (skip $f — not present locally)"
  fi
done

echo "→ Setting up venv + dependencies..."
ssh_run "cd $REMOTE_DIR && python3.11 -m venv .venv && \
  .venv/bin/pip install --quiet --upgrade pip && \
  .venv/bin/pip install --quiet -r requirements.txt"

echo "→ Installing systemd unit..."
ssh_run "cp $REMOTE_DIR/scripts/watcher.service /etc/systemd/system/watcher.service && \
  systemctl daemon-reload && \
  systemctl enable watcher.service && \
  systemctl restart watcher.service"

sleep 3
echo "→ Service status:"
ssh_run "systemctl status watcher.service --no-pager -l | head -20" || true

echo
echo "✓ VPS bootstrap complete."
echo "  Tail logs with: ssh $REMOTE 'journalctl -u watcher -f'"
