#!/usr/bin/env bash
# Run the walrus-discovery-indexer against the LOCAL devstack stack — no .env
# editing. Extracts everything from the running stack:
#   - WALRUS_PACKAGE_ID + the local aggregator URL from the stack's
#     deployment.json (blob inspection goes through the aggregator's HTTP API:
#     the local cluster's committee hostnames only resolve inside Docker, so
#     the @mysten/walrus SDK read path cannot reach the storage nodes from
#     a host process)
#   - SUI_GRPC_URL from the validator's host-published port (gRPC checkpoint
#     streaming 400s through the Traefik-routed :9000)
# Full runbook: chat-app/docs/DEVSTACK.md
set -euo pipefail

CHAT_APP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$CHAT_APP/.." && pwd)"
INDEXER="$REPO_ROOT/walrus-discovery-indexer"
DEPLOYMENT="$CHAT_APP/.devstack/stacks/chat-app-local/deployment.json"

if [[ ! -f "$DEPLOYMENT" ]]; then
  echo "error: $DEPLOYMENT not found." >&2
  echo "Start the stack first:  cd chat-app && node_modules/.bin/devstack up" >&2
  exit 1
fi
if [[ ! -d "$INDEXER/node_modules" ]]; then
  echo "error: indexer dependencies not installed." >&2
  echo "Run:  cd walrus-discovery-indexer && npx pnpm@10 install" >&2
  exit 1
fi

json() { node -p "JSON.parse(require('fs').readFileSync('$DEPLOYMENT','utf8')).networks.localnet$1"; }

WALRUS_PACKAGE_ID="$(json .values.walrus.walrusPackageId)"
WALRUS_AGGREGATOR_URL="$(json .values.walrus.aggregatorUrl)"

VALIDATOR="$(docker ps --format '{{.Names}}' | grep -m1 -- '-sui-validator$' || true)"
if [[ -z "$VALIDATOR" ]]; then
  echo "error: no running devstack sui-validator container found — is the stack up?" >&2
  exit 1
fi
SUI_GRPC_URL="http://$(docker port "$VALIDATOR" 9000 | head -1 | sed 's/0\.0\.0\.0/127.0.0.1/')"

PORT="${PORT:-3001}"
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "error: port $PORT is already in use (another indexer?) — stop it or set PORT=<other>." >&2
  exit 1
fi

echo "SUI_GRPC_URL=$SUI_GRPC_URL"
echo "WALRUS_PACKAGE_ID=$WALRUS_PACKAGE_ID"
echo "WALRUS_AGGREGATOR_URL=$WALRUS_AGGREGATOR_URL"

cd "$INDEXER"
exec env \
  NETWORK=localnet \
  SUI_GRPC_URL="$SUI_GRPC_URL" \
  WALRUS_PACKAGE_ID="$WALRUS_PACKAGE_ID" \
  WALRUS_AGGREGATOR_URL="$WALRUS_AGGREGATOR_URL" \
  PORT="$PORT" \
  node_modules/.bin/tsx src/index.ts
