---
name: spin-up-local-devstack
description: Use when the user wants a FULLY-LOCAL stack (no testnet dependency) for Sui Stack Messaging — including a LOCAL Seal key server so message decryption works on localnet. Uses @mysten-incubation/devstack to compose a local Sui node + local-keygen Seal + (optional) local Walrus + published Move packages + the chat-app from one config file. The localnet counterpart to spin-up-e2e-stack (which is testnet-first and cannot decrypt on localnet). Requires Docker + Node >= 24. Trigger phrases - "fully local stack", "localnet with working Seal", "local seal key server", "devstack", "no testnet dependency", "local encryption", "decrypt on localnet", "all-local messaging stack".
---

# Spin up a fully-local stack with devstack (incl. local Seal)

A one-command, all-local Sui Stack Messaging stack via `@mysten-incubation/devstack`: local Sui node +
a **local Seal key server** + the messaging Move package + a browser dev-wallet + the chat-app. The
payoff is that message **decryption works fully locally** — the testnet-first
[`spin-up-e2e-stack`](../spin-up-e2e-stack/SKILL.md) can't decrypt on localnet (Seal has no localnet;
the canonical key servers can't authorize localnet group objects).

This was validated end-to-end (`create → send → DECRYPT`). The chat-app-side integration is documented
in [`chat-app/docs/DEVSTACK.md`](../../../chat-app/docs/DEVSTACK.md); the friction log + upstream doc
links are in [`reference/NOTES.md`](./reference/NOTES.md).

## Requirements

- **Docker, running.** sui / seal run as containers; first boot pulls images (slow).
- **Node >= 24** (devstack `engines`). With nvm: `nvm install 24 && nvm use 24`.
- **pnpm 10.x for installs.** On pnpm v11 a fresh install trips the esbuild build gate and the
  `minimumReleaseAge` floor on devstack's fresh transitive deps. Use `npx pnpm@10 install`. See
  [`docs/pnpm-v11-troubleshooting.md`](../../../docs/pnpm-v11-troubleshooting.md).
- **No native localnet on `:9000`.** Stop any `sui start` first.
- The incubation deps stay **chat-app devDependencies only** (never the canonical SDK).

## Run

```bash
cd chat-app
npx pnpm@10 install      # devDeps: @mysten-incubation/devstack@0.1.1, @mysten-incubation/dev-wallet@0.3.0, @mysten/signers@1.0.5
pnpm devstack up         # sui + local Seal + publish + codegen + serve  (add --renderer plain for clean logs)
# offline sanity check (no Docker): pnpm devstack config
```

Open the printed `http://dev.chat-app-local.chat-app.localhost:5175`, connect the **Dev Wallet**
(funded `publisher`/`alice`/`bob`), create a group, send, refresh → it decrypts. Send/decrypt also need
the relayer (below).

## How it fits together

`devstack up` brings up: Sui node → publisher account → messaging package publish → local-keygen Seal →
dev-wallet server → chat-app (Vite), writing typed config to `chat-app/src/generated/` (gitignored).
The chat-app consumes it through `vite.config.ts` (`devstackVitePlugin()` aliases `@generated`; a
`virtual:devstack-app-config` shim keeps it dev-only) and `src/lib/devstack-config.ts`. Full walkthrough:
[`chat-app/docs/DEVSTACK.md`](../../../chat-app/docs/DEVSTACK.md).

The load-bearing, non-obvious bits (all handled in `chat-app/devstack.config.ts` + `devstack-config.ts`):

- **Publishing the package.** devstack does one `Transaction.publish({ modules })`, which *merges*
  bundled unpublished deps into one package. `sui_groups` ships a committed `Published.toml`, so the
  `-e testnet` build links its testnet id (absent on localnet) instead of bundling. Fix: materialize a
  gitignored copy of `sui_groups` with `Published.toml`/`Move.lock` stripped + a local Move dep, patch
  `suins` MVR→git, strip messaging's `Published.toml`. Net: messaging + sui_groups merge into one local
  package id (so `messaging` and `permissionedGroups` configs share it). The app recovers the
  namespace/version singletons + the groups id from the publish tx via GraphQL at bootstrap.
- **Seal: one server, `sealThreshold: 1`.** Two local-keygen servers collide in codegen in 0.1.1.
- **Dev-wallet: register it yourself.** `devstackVitePlugin()` only aliases `@generated` — it does NOT
  inject a wallet. devstack runs the wallet *server* (funded accounts); the app builds a
  `DevstackSignerAdapter` from `@generated/dapp-kit/config` and hands it to dApp Kit via
  `devWalletInitializer({ mountUI: true })` in `createDAppKit({ walletInitializers })`.
  Serialize sign calls (the DevWallet allows one pending sign; dApp Kit doesn't queue).

## Relayer

devstack does not run the reference relayer; send/fetch go through it. Run it separately
([`spin-up-relayer`](../spin-up-relayer/SKILL.md)) on the host, pointed at the **direct host-published
validator port** (not the Traefik-routed `:9000`, which 400s on gRPC):

```bash
docker port <devstack-…-sui-validator> 9000        # e.g. 127.0.0.1:51000
# relayer/.env: SUI_RPC_URL=http://127.0.0.1:51000 ; GROUPS_PACKAGE_ID=<merged id from src/generated/packages.ts>
cd relayer && cargo run                             # :3000 ; the chat-app reads VITE_RELAYER_URL (default localhost:3000)
```

## Walrus (optional)

Walrus is **off the critical path for the create → send → decrypt loop**: decryption never touches
it (delivery = relayer store + on-chain refs; Walrus is recovery / attachments only), so leaving it
out doesn't compromise local decryption. Only message **attachments** need it.

The seam that stays non-local is **archival** — the reference relayer archives to its default
**testnet** Walrus. Making *that* local is a tracked follow-up (not done here): devstack offers
`walrus({ local: { nodeCount, shards } })` + `walCoin`, but the relayer + chat-app talk **HTTP** to a
publisher/aggregator gateway (not the Walrus SDK) — whether devstack's local Walrus exposes those is
the open question — and it also needs repointing the relayer's `WALRUS_PUBLISHER_URL`/`AGGREGATOR_URL`,
enabling attachments (off in devstack mode), and wiring the indexer + SDK `RecoveryTransport`. To
experiment now, add `walrus({ local })` + `walCoin` to `devstack.config.ts` and wire `VITE_WALRUS_*`.

## Gotchas (full list in `reference/NOTES.md`)

- **First boot is slow** (image pulls). `.devstack/` + `src/generated/` are gitignored (regenerated each `up`).
- **Reset:** `devstack wipe --yes`; hard Docker reset `docker rm -f $(docker ps -aq --filter name=devstack)`
  (`devstack prune` only removes idle groups). Re-emit codegen: `devstack apply`.
- **"A signing request is already pending"** = concurrent signs vs the DevWallet's one-pending model → serialize app-side.
- **Connect hangs at "Confirm connection in the wallet"** = no approval UI — `mountUI: true` missing
  in `devWalletInitializer(...)`, or `walletInitializers` not passed to `createDAppKit`.
- **Relayer "grpc-status header missing, HTTP 400"** = gRPC through Traefik → use the host-published port.

## Cross-links

- Testnet-first / manual localnet path: [`spin-up-e2e-stack`](../spin-up-e2e-stack/SKILL.md).
- Run the relayer: [`spin-up-relayer`](../spin-up-relayer/SKILL.md).
- Why Seal can't work on a localnet + testnet-Seal hybrid: [`debug-encryption-flow`](../debug-encryption-flow/SKILL.md) (Stage 3).
- devstack docs: <https://github.com/MystenLabs/ts-sdks-incubation/tree/main/packages/docs/content/devstack>
  · dev-wallet docs: <https://github.com/MystenLabs/ts-sdks-incubation/tree/main/packages/docs/content/dev-wallet>
