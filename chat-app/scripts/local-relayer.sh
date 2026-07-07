#!/usr/bin/env bash
# Run the reference relayer against the LOCAL devstack stack — no .env editing.
# Extracts everything from the running stack:
#   - GROUPS_PACKAGE_ID + local Walrus publisher/aggregator URLs from the
#     stack's deployment.json
#   - SUI_RPC_URL from the validator's host-published port (the relayer's gRPC
#     checkpoint stream 400s through the Traefik-routed :9000)
# Inline env wins over relayer/.env (dotenv does not override set variables).
# Full runbook: chat-app/docs/DEVSTACK.md
set -euo pipefail

CHAT_APP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$CHAT_APP/.." && pwd)"
DEPLOYMENT="$CHAT_APP/.devstack/stacks/chat-app-local/deployment.json"

if [[ ! -f "$DEPLOYMENT" ]]; then
  echo "error: $DEPLOYMENT not found." >&2
  echo "Start the stack first:  cd chat-app && node_modules/.bin/devstack up" >&2
  exit 1
fi

json() { node -p "JSON.parse(require('fs').readFileSync('$DEPLOYMENT','utf8')).networks.localnet$1"; }

GROUPS_PACKAGE_ID="$(json .packages.sui_stack_messaging.id)"
WALRUS_PUBLISHER_URL="$(json .values.walrus.publisherUrl)"
WALRUS_AGGREGATOR_URL="$(json .values.walrus.aggregatorUrl)"

VALIDATOR="$(docker ps --format '{{.Names}}' | grep -m1 -- '-sui-validator$' || true)"
if [[ -z "$VALIDATOR" ]]; then
  echo "error: no running devstack sui-validator container found — is the stack up?" >&2
  exit 1
fi
SUI_RPC_URL="http://$(docker port "$VALIDATOR" 9000 | head -1 | sed 's/0\.0\.0\.0/127.0.0.1/')"

PORT="${PORT:-3000}"
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "error: port $PORT is already in use (another relayer?) — stop it or set PORT=<other>." >&2
  exit 1
fi

echo "SUI_RPC_URL=$SUI_RPC_URL"
echo "GROUPS_PACKAGE_ID=$GROUPS_PACKAGE_ID"
echo "WALRUS_PUBLISHER_URL=$WALRUS_PUBLISHER_URL"
echo "WALRUS_AGGREGATOR_URL=$WALRUS_AGGREGATOR_URL"

# Fast dev-loop archival defaults; override any of these in your shell.
exec env \
  PORT="$PORT" \
  SUI_RPC_URL="$SUI_RPC_URL" \
  GROUPS_PACKAGE_ID="$GROUPS_PACKAGE_ID" \
  WALRUS_PUBLISHER_URL="$WALRUS_PUBLISHER_URL" \
  WALRUS_AGGREGATOR_URL="$WALRUS_AGGREGATOR_URL" \
  WALRUS_SYNC_INTERVAL_SECS="${WALRUS_SYNC_INTERVAL_SECS:-15}" \
  WALRUS_SYNC_MESSAGE_THRESHOLD="${WALRUS_SYNC_MESSAGE_THRESHOLD:-1}" \
  WALRUS_STORAGE_EPOCHS="${WALRUS_STORAGE_EPOCHS:-1}" \
  RUST_LOG="${RUST_LOG:-messaging_relayer=info}" \
  cargo run --manifest-path "$REPO_ROOT/relayer/Cargo.toml"
