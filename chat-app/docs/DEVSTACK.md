# Local devstack integration

How the chat-app runs **fully locally** — local Sui node + a **local Seal key server** + the messaging
Move package + a browser dev-wallet — via `@mysten-incubation/devstack`, so message **decryption works
on localnet** with no testnet dependency.

> Why this exists: Seal has no localnet. The canonical testnet key servers can't authorize localnet
> group objects, so a localnet-Sui + testnet-Seal hybrid **can't decrypt**. devstack's
> `seal({ mode: 'local-keygen' })` runs a real Seal key server against the in-stack node, closing that
> gap. This is the localnet counterpart to the testnet-first `spin-up-e2e-stack`.

It's a **dev-only** path: `@mysten-incubation/devstack` + `@mysten-incubation/dev-wallet` are
`chat-app` devDependencies, and every devstack code path is gated so a normal `pnpm dev` / `pnpm build`
(testnet) never imports them.

## Run it

```bash
cd chat-app
npx pnpm@10 install      # see "pnpm" below
pnpm devstack up         # local Sui + local Seal + publish + codegen + serve
```

Open the printed `http://dev.chat-app-local.chat-app.localhost:5175`, connect the **Dev Wallet**
(funded `publisher`/`alice`/`bob`), create a group, send, and it decrypts locally. For send/decrypt you
also need the **relayer** running (devstack doesn't supervise it) — see "Relayer" below.

Requires **Docker** running and **Node >= 24** (`nvm install 24`). First boot pulls images (slow).

## What `devstack up` does

Brings up, from one config (`devstack.config.ts`): the Sui node → a publisher account → publishes the
messaging Move package → the local-keygen Seal key server → the dev-wallet server (funded accounts) →
this Vite app. It writes typed config to `src/generated/` (gitignored).

## The pieces (what we added and why)

| File | What it does |
|---|---|
| `devstack.config.ts` | The stack definition. Also **materializes patched build sources** under `.devstack/` (see "Publishing" below) — the canonical Move package is never touched. |
| `vite.config.ts` | Adds `devstackVitePlugin()` (dev-only; aliases `@generated`) and a `virtual:devstack-app-config` **shim**. The shim composes the generated config into one `devstack` object, including a dev-wallet `walletInitializers` entry — all only in the active branch, so committed code never statically imports `@generated` or the incubation packages. |
| `src/lib/devstack-config.ts` | The loader. Reads the shim, derives the local network, builds a **gRPC base client** with MVR overrides, and recovers on-chain ids (see "Recovery"). `isDevstack` is the on/off switch the rest of the app branches on. |
| `src/contexts/MessagingClientContext.tsx` | In devstack mode, builds the messaging client from the loader (local RPC + seal serverConfigs + package ids) instead of env; sets `sealThreshold: 1`; **serializes wallet signs**. |
| `src/lib/dapp-kit.ts`, `src/main.tsx` | The `createDAppKit` instance. Registers a `localnet` network (so the dev-wallet's `sui:localnet` chain matches), defaults to it under devstack, and passes the shim's `walletInitializers` through. |
| `.gitignore` | Ignores `.devstack/` (patched Move sources) and `src/generated/` (regenerated every `up`). |

## Publishing the Move package (the tricky bit)

`localPackage()` builds offline with `-e testnet` and does a single `Transaction.publish({ modules })`,
which **merges** all bundled unpublished deps into **one** package. Two problems for us:

1. `sui_groups` ships a committed `Published.toml` (`[published.testnet]`), so `-e testnet` *links*
   against its testnet id (which doesn't exist on localnet) instead of bundling it.
2. `suins` is an MVR dep that doesn't resolve on localnet.

`devstack.config.ts` fixes both by materializing gitignored copies under `.devstack/`: it clones
`sui_groups` at the pinned rev and **strips its `Published.toml`/`Move.lock`** (so it bundles as a
local, unpublished dep), patches messaging's `suins` MVR → git, and strips messaging's own
`Published.toml`. Net result on localnet: messaging + sui_groups + suins are **one merged package**, so
`packageConfig.messaging` and `packageConfig.permissionedGroups` share that single id.

## Recovery (what codegen doesn't surface)

The merged publish means `config.packages` only has the messaging id — not the `MessagingNamespace`/
`Version` singletons or the `permissioned_group` (groups) id the SDK needs. `devstack-config.ts`
recovers them from the publish tx at bootstrap via the local GraphQL (newer schema: `/graphql` path,
`transaction(digest:)`, `object{ previousTransaction }`).

## Dev-wallet

devstack runs the wallet **server** (funded accounts; keys stay server-side) but does **not** register
a wallet in the app. The shim builds a `DevstackSignerAdapter` from the generated `dappKitConfig` and
wraps it in dev-wallet's `devWalletInitializer({ mountUI: true })`, which `src/lib/dapp-kit.ts` passes
to `createDAppKit({ walletInitializers })` — dApp Kit then registers the wallet (so `ConnectButton`
lists it), initializes the adapter, and mounts the approval panel. Because the DevWallet allows only
one pending sign (and dApp Kit doesn't queue wallet requests), the context still **serializes** sign
requests (session-key + tx signing can otherwise overlap, especially under React StrictMode) to avoid
"a signing request is already pending".

## Seal — one key server

We run a single local-keygen Seal server (two collide in codegen in devstack 0.1.1) and set
`encryption.sealThreshold: 1` to match.

## Relayer

devstack covers Sui / Seal / packages / wallet / app; send & fetch still go through the reference
relayer. Run it separately (host process) pointed at the **direct, host-published validator port**, not
the Traefik-routed `:9000` (gRPC fails through the router):

```bash
docker port <devstack-…-sui-validator> 9000     # e.g. 127.0.0.1:51000
# relayer/.env: SUI_RPC_URL=http://127.0.0.1:51000
#               GROUPS_PACKAGE_ID=<merged messaging/groups id from src/generated/packages.ts>
cd ../relayer && cargo run
```

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
