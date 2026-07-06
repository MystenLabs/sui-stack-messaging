---
name: spin-up-local-devstack
description: Use when the user wants a FULLY-LOCAL stack (no testnet dependency) for Sui Stack Messaging — including a LOCAL Seal key server so message decryption works on localnet, and a LOCAL Walrus cluster (publisher + aggregator) so attachments and relayer archival stay local too. Uses @mysten-incubation/devstack to compose a local Sui node + local-keygen Seal + local Walrus + published Move packages + the chat-app from one config file. The localnet counterpart to spin-up-e2e-stack (which is testnet-first and cannot decrypt on localnet). Requires Docker + Node >= 24. Trigger phrases - "fully local stack", "localnet with working Seal", "local seal key server", "devstack", "no testnet dependency", "local encryption", "decrypt on localnet", "local walrus", "local attachments", "local archival", "all-local messaging stack".
---

# Spin up a fully-local stack with devstack (incl. local Seal + local Walrus)

A one-command, all-local Sui Stack Messaging stack via `@mysten-incubation/devstack`: local Sui node +
a **local Seal key server** + a **local Walrus cluster** (storage nodes + publisher + aggregator +
upload relay) + the messaging Move package + a browser dev-wallet + the chat-app. The payoff is that
message **decryption works fully locally** — the testnet-first
[`spin-up-e2e-stack`](../spin-up-e2e-stack/SKILL.md) can't decrypt on localnet (Seal has no localnet;
the canonical key servers can't authorize localnet group objects) — and **attachments + relayer
archival never touch testnet** either.

Validated end-to-end (`create → send → DECRYPT`, attachment upload via the local publisher +
round-trip via the local aggregator, relayer quilt archival to local Walrus with indexer tags intact).
The chat-app-side integration is documented in
[`chat-app/docs/DEVSTACK.md`](../../../chat-app/docs/DEVSTACK.md); the friction log + upstream doc
links are in [`reference/NOTES.md`](./reference/NOTES.md).

## Requirements

- **Docker, running.** sui / seal / walrus run as containers; first boot pulls + builds images (the
  Walrus image is the slow one; cached after).
- **Node >= 24** (devstack `engines`). With nvm: `nvm install 24 && nvm use 24`.
- **Host `sui` CLI** — `devstack codegen` requires it (no Docker fallback since devstack 0.3).
- **pnpm 10.x for installs.** On pnpm v11 a fresh install trips the esbuild build gate and the
  `minimumReleaseAge` floor on devstack's fresh transitive deps. Use `npx pnpm@10 install`. See
  [`docs/pnpm-v11-troubleshooting.md`](../../../docs/pnpm-v11-troubleshooting.md).
- **No native localnet on `:9000`.** Stop any `sui start` first.
- The incubation dep stays a **chat-app devDependency only** (never the canonical SDK).

## Run

```bash
cd chat-app
npx pnpm@10 install      # devDep: @mysten-incubation/devstack@0.7.0
pnpm devstack up         # sui + Seal + Walrus + publish + codegen + serve  (add --renderer plain for clean logs)
# offline sanity check (no Docker): pnpm devstack config
# upgrading devstack minors? `pnpm devstack wipe --yes` once first — stack state doesn't migrate
```

Open the printed `http://dev.chat-app-local.chat-app.localhost:5175`, connect the **Dev Wallet**
(funded `publisher`/`alice`/`bob`; connecting is a user click — no auto-connect), create a group, send
— it decrypts, and attachments upload/render via the local Walrus. Send/decrypt also need the relayer
(below).

## How it fits together

`devstack up` brings up: Sui node → publisher account → messaging package publish → local-keygen Seal
→ local Walrus (Move deploy + committee + publisher/aggregator/upload-relay) → dev-wallet server →
chat-app (Vite), writing **id-free** typed stubs to `chat-app/src/generated/` (gitignored); values
resolve through the deployment envelope the Vite plugin injects. The chat-app consumes it through
`vite.config.ts` (`devstackVitePlugin()` + a `virtual:devstack-app-config` shim that keeps `@generated`
dev-only) and `src/lib/devstack-config.ts`. Full walkthrough:
[`chat-app/docs/DEVSTACK.md`](../../../chat-app/docs/DEVSTACK.md).

The load-bearing, non-obvious bits (all handled in `chat-app/devstack.config.ts` + `devstack-config.ts`):

- **Publishing the package.** devstack does one `Transaction.publish({ modules })`, which *merges*
  bundled unpublished deps into one package. `sui_groups` ships a committed `Published.toml`, so the
  `-e testnet` build links its testnet id (absent on localnet) instead of bundling. Fix: materialize a
  gitignored copy of `sui_groups` with `Published.toml`/`Move.lock` stripped + a local Move dep, patch
  `suins` MVR→git, strip messaging's `Published.toml`. (devstack 0.7 scrubs `Move.lock` pinned/env
  sections itself, but never `Published.toml`.) Net: messaging + sui_groups merge into one local
  package id (so `messaging` and `permissionedGroups` configs share it). The namespace/version
  singletons come from the `capture` option on `localPackage()` — no chain reads at bootstrap.
- **Seal: one server, `sealThreshold: 1`.** A deliberate lightweight choice (the 0.1.1 two-server
  codegen collision is fixed in 0.7).
- **Walrus: all three client services on by default.** Bare `walrus()` boots publisher + aggregator +
  upload relay; the publisher's wallet is deploy-funded, so browser accounts need **no WAL** (the
  publisher pays; `walCoin` is only for `@mysten/walrus` SDK signing paths). The messaging SDK's
  `WalrusHttpStorageAdapter` talks HTTP to publisher/aggregator; the upload relay is unused by it.
- **Dev-wallet: injected by the plugin.** `devstackVitePlugin()` injects + registers the dev wallet on
  the page in dev (wallet-standard auto-discovery) — no app-side initializer. Serialize sign calls
  (the DevWallet allows one pending sign; dApp Kit doesn't queue).

## Relayer

devstack does not run the reference relayer; send/fetch go through it. Run it separately
([`spin-up-relayer`](../spin-up-relayer/SKILL.md)) on the host, pointed at the **direct host-published
validator port** (not the Traefik-routed `:9000`, which 400s on gRPC), and at the **local Walrus
daemons** (else it archives localnet messages to the public testnet publisher — archival can't be
disabled, only repointed):

```bash
docker port <devstack-…-sui-validator> 9000        # e.g. 127.0.0.1:51000
# relayer/.env:
#   SUI_RPC_URL=http://127.0.0.1:51000
#   GROUPS_PACKAGE_ID=<merged id — packages.sui_stack_messaging.id in chat-app/.devstack/stacks/chat-app-local/deployment.json>
#   WALRUS_PUBLISHER_URL=http://walrus-publisher.chat-app-local.chat-app.localhost:9185
#   WALRUS_AGGREGATOR_URL=http://walrus-aggregator.chat-app-local.chat-app.localhost:9185
#   WALRUS_SYNC_INTERVAL_SECS=15 ; WALRUS_SYNC_MESSAGE_THRESHOLD=1 ; WALRUS_STORAGE_EPOCHS=1   # fast dev loop
cd relayer && cargo run                             # :3000 ; the chat-app reads VITE_RELAYER_URL (default localhost:3000)
```

The `*.localhost` hostnames resolve to loopback on the host, where the devstack router listens on
`127.0.0.1:9185` and dispatches by `Host` header — no extra wiring. (gRPC is the exception; hence the
direct validator port.)

## Walrus notes

Walrus is **off the critical path for the create → send → decrypt loop** (delivery = relayer store +
on-chain refs). It carries **attachments** (live) and **archival** (relayer quilts, tagged
`source=sui-messaging-relayer` for the indexer). Still non-local: the `walrus-discovery-indexer` +
the SDK `RecoveryTransport` (recovery e2e) — tracked separately in SEW-1004 tiers 2b/2c.

## Gotchas (full list in `reference/NOTES.md`)

- **First boot is slow** (Walrus image build). `.devstack/` + `src/generated/` are gitignored.
- **Reset:** `devstack wipe --yes`; hard Docker reset `docker rm -f $(docker ps -aq --filter name=devstack)`
  (`devstack prune` only removes idle groups). Re-emit codegen: `devstack apply`.
- **Don't change `localPackage` identity options (e.g. `mvrPlaceholder`) on a live stack** — the
  reconciler restart-loops against the cached publish record. Wipe + fresh `up` to converge.
- **"A signing request is already pending"** = concurrent signs vs the DevWallet's one-pending model → serialize app-side.
- **Relayer "grpc-status header missing, HTTP 400"** = gRPC through Traefik → use the host-published port.

## Cross-links

- Testnet-first / manual localnet path: [`spin-up-e2e-stack`](../spin-up-e2e-stack/SKILL.md).
- Run the relayer: [`spin-up-relayer`](../spin-up-relayer/SKILL.md).
- Why Seal can't work on a localnet + testnet-Seal hybrid: [`debug-encryption-flow`](../debug-encryption-flow/SKILL.md) (Stage 3).
- devstack docs: <https://github.com/MystenLabs/ts-sdks-incubation/tree/main/packages/docs/content/devstack>
  · dev-wallet docs: <https://github.com/MystenLabs/ts-sdks-incubation/tree/main/packages/docs/content/dev-wallet>
