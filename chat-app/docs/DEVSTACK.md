# Local devstack integration

How the chat-app runs **fully locally** — local Sui node + a **local Seal key server** + a **local
Walrus cluster** (storage nodes + publisher + aggregator) + the messaging Move package + a browser
dev-wallet — via `@mysten-incubation/devstack`, so message **decryption works on localnet** and
**attachments + relayer archival never touch testnet**.

> Why this exists: Seal has no localnet. The canonical testnet key servers can't authorize localnet
> group objects, so a localnet-Sui + testnet-Seal hybrid **can't decrypt**. devstack's
> `seal({ mode: 'local-keygen' })` runs a real Seal key server against the in-stack node, closing that
> gap. Since devstack 0.6/0.7, `walrus()` also boots the release **publisher/aggregator/upload-relay**
> services, closing the last cross-network seam (attachments and archival used to hit testnet Walrus).
> This is the localnet counterpart to the testnet-first `spin-up-e2e-stack`.

It's a **dev-only** path: `@mysten-incubation/devstack` is a `chat-app` devDependency, and every
devstack code path is gated so a normal `pnpm dev` / `pnpm build` (testnet) never imports it.

## Run it

```bash
cd chat-app
npx pnpm@10 install      # see "pnpm" below
pnpm devstack up         # local Sui + Seal + Walrus + publish + codegen + serve
```

Open the printed `http://dev.chat-app-local.chat-app.localhost:5175`, connect the **Dev Wallet**
(funded `publisher`/`alice`/`bob`), create a group, send — messages decrypt and attachments upload
locally. For send/decrypt you also need the **relayer** running (devstack doesn't supervise it) — see
"Relayer" below.

Requires **Docker** running, **Node >= 24** (`nvm install 24`), and a host **`sui` CLI** (used by
codegen). First boot pulls/builds images (the Walrus image build is the slow one; later boots reuse
it). Upgrading across devstack minor versions? Run `pnpm devstack wipe` once first — on-disk stack
state does not migrate.

## What `devstack up` does

Brings up, from one config (`devstack.config.ts`): the Sui node → a publisher account → publishes the
messaging Move package → the local-keygen Seal key server → the local Walrus cluster (deploys the
wal/walrus Move packages, activates a storage-node committee, starts publisher + aggregator +
upload-relay) → the dev-wallet server (funded accounts) → this Vite app. It writes **id-free typed
stubs** to `src/generated/` (gitignored); actual ids/URLs resolve at dev/build time through the
deployment envelope (`__DEVSTACK_DEPLOYMENT__`) the devstack Vite plugin injects.

## The pieces (what we added and why)

| File | What it does |
|---|---|
| `devstack.config.ts` | The stack definition. Also **materializes patched build sources** under `.devstack/` (see "Publishing" below) — the canonical Move package is never touched. |
| `vite.config.ts` | Adds `devstackVitePlugin()` (dev-only; aliases `@generated`, injects the deployment envelope and the dev wallet) and a `virtual:devstack-app-config` **shim**. The shim resolves the generated `config`/`seal`/`walrus` modules for the local network into one `devstack` object — only in the active branch, so committed code never statically imports `@generated` (whose stubs throw without an injected envelope). |
| `src/lib/devstack-config.ts` | The loader. Reads the shim, derives the local network, builds a **gRPC base client** with MVR overrides, and assembles the SDK `packageConfig` from the captured object ids (see "Captured objects"). `isDevstack` is the on/off switch the rest of the app branches on. |
| `src/contexts/MessagingClientContext.tsx` | In devstack mode, builds the messaging client from the loader (local RPC + seal serverConfigs + package ids + **Walrus publisher/aggregator URLs** for the attachments adapter) instead of env; sets `sealThreshold: 1`. |
| `src/lib/queued-signer.ts` | `QueuedCurrentAccountSigner` — dApp Kit's `CurrentAccountSigner` with **serialized personal-message signs** (the DevWallet allows one pending sign). |
| `src/lib/dapp-kit.ts`, `src/main.tsx` | The `createDAppKit` instance. Registers a `localnet` network (so the dev-wallet's `sui:localnet` chain matches) and defaults to it under devstack. In dev it also registers the instance with devstack's test bridge (Playwright `connectAs`). |
| `.gitignore` | Ignores `.devstack/` (patched Move sources + stack state) and `src/generated/` (regenerated every `up`). |

## Publishing the Move package (the tricky bit)

`localPackage()` builds offline with `-e testnet` and does a single `Transaction.publish({ modules })`,
which **merges** all bundled unpublished deps into **one** package. Two problems for us:

1. `sui_groups` ships a committed `Published.toml` (`[published.testnet]`), so `-e testnet` *links*
   against its testnet id (which doesn't exist on localnet) instead of bundling it. devstack scrubs
   `Move.lock` pinned/env sections automatically (0.7.0) but never touches `Published.toml`.
2. `suins` is an MVR dep that doesn't resolve on localnet.

`devstack.config.ts` fixes both by materializing gitignored copies under `.devstack/`: it clones
`sui_groups` at the pinned rev and **strips its `Published.toml`/`Move.lock`** (so it bundles as a
local, unpublished dep), patches messaging's `suins` MVR → git, and strips messaging's own
`Published.toml`. Net result on localnet: messaging + sui_groups + suins are **one merged package**, so
`packageConfig.messaging` and `packageConfig.permissionedGroups` share that single id.

## Captured objects (what codegen surfaces now)

The merged publish creates the `MessagingNamespace`/`Version` singletons the SDK's
`packageConfig.messaging` needs. The `capture` option on `localPackage()` grabs them from the publish
output by type suffix and surfaces them as `packages.sui_stack_messaging.objects` in the generated
config — no chain reads at app bootstrap. (The old GraphQL publish-tx recovery is gone.) The groups id
needs no capture: on localnet it IS the merged package id.

## Dev-wallet

devstack runs the wallet **server** (funded accounts; keys stay server-side), and the devstack Vite
plugin **injects and registers** the wallet on the page in dev — wallet-standard auto-discovery, so
dApp Kit's `ConnectButton` lists it with no app-side initializer code. Connecting is a user click
(devstack ≥ 0.2 removed auto-connect; e2e drives it via the test bridge instead). Because the
DevWallet allows only one pending sign (and dApp Kit doesn't queue wallet requests), the app's signer
(`QueuedCurrentAccountSigner`, `src/lib/queued-signer.ts`) **serializes** personal-message signs —
the Seal session-key ceremony and relayer request signing can otherwise overlap, especially under
React StrictMode, throwing "a signing request is already pending".

## Seal — one key server

We run a single local-keygen Seal server and set `encryption.sealThreshold: 1` to match. (One server
is a deliberate lightweight choice; devstack 0.7.0 can boot several without the codegen collision
0.1.1 had.)

## Walrus — local publisher/aggregator

`walrus()` in `devstack.config.ts` boots a 1-node local Walrus cluster **plus** the release
publisher, aggregator, and upload-relay client services (all on by default). The publisher's wallet is
created and funded by the deploy one-shot — **browser accounts need no WAL**; the publisher pays for
storage. The routed URLs land in the generated `walrus` bindings:

- `http://walrus-publisher.chat-app-local.chat-app.localhost:9185`
- `http://walrus-aggregator.chat-app-local.chat-app.localhost:9185`

The shim feeds them into `MessagingClientContext`, which builds the SDK's `WalrusHttpStorageAdapter`
from them — so **file attachments work fully locally** (`PUT /v1/quilts` to the publisher, `GET
/v1/blobs/by-quilt-patch-id/…` from the aggregator). Outside devstack the adapter still comes from
`VITE_WALRUS_*` env (testnet). The upload relay is unused by the messaging SDK's HTTP adapter; it
serves `@mysten/walrus` SDK upload flows if you switch adapters.

## Relayer

devstack covers Sui / Seal / Walrus / packages / wallet / app; send & fetch still go through the
reference relayer. Run it separately (host process) pointed at the **direct, host-published validator
port**, not the Traefik-routed `:9000` (gRPC fails through the router). Point its Walrus vars at the
local daemons — otherwise it archives localnet messages to the **public testnet publisher** (its
default; archival cannot be disabled, only repointed):

```bash
docker port <devstack-…-sui-validator> 9000     # e.g. 127.0.0.1:51000
# relayer/.env:
#   SUI_RPC_URL=http://127.0.0.1:51000
#   GROUPS_PACKAGE_ID=<merged messaging/groups id — packages.sui_stack_messaging.id in
#                      .devstack/stacks/chat-app-local/deployment.json>
#   WALRUS_PUBLISHER_URL=http://walrus-publisher.chat-app-local.chat-app.localhost:9185
#   WALRUS_AGGREGATOR_URL=http://walrus-aggregator.chat-app-local.chat-app.localhost:9185
#   WALRUS_SYNC_INTERVAL_SECS=15      # dev loop: archive fast (default 3600)
#   WALRUS_SYNC_MESSAGE_THRESHOLD=1   # dev loop: archive every message (default 50)
#   WALRUS_STORAGE_EPOCHS=1           # local epochs are 24h (default 5)
cd ../relayer && cargo run
```

The `*.localhost` hostnames resolve to loopback on macOS and Linux hosts, where the devstack router
listens on `127.0.0.1:9185` and dispatches by `Host` header — the relayer reaches the daemons with no
extra wiring.

## SDK dependency

The chat-app depends on the **published** `@mysten/sui-stack-messaging` (Mode A — no `link:` / no
`build:deps`). Forks ship the published SDK; that's the intended reference posture.

## pnpm

This repo targets pnpm 10.x. On pnpm v11 a fresh install trips the esbuild build gate and (for the
incubation deps) the `minimumReleaseAge` supply-chain floor — use `npx pnpm@10 install`. The
host-service runs `node_modules/.bin/vite` directly (not `pnpm exec vite`) so the dev server never
triggers pnpm's deps-purge in its non-TTY child.

## More

- Friction log + upstream doc links: [`.claude/skills/spin-up-local-devstack/reference/NOTES.md`](../../.claude/skills/spin-up-local-devstack/reference/NOTES.md)
- Runbook: the `spin-up-local-devstack` skill.
