# devstack + dev-wallet notes for the sui-stack-messaging chat-app

What we learned wiring `@mysten-incubation/devstack` into the chat-app for a **fully-local,
end-to-end-encrypted** stack (local Sui + local-keygen Seal + local Walrus + published package +
dev-wallet), verified `create → send → DECRYPT` plus attachment upload/round-trip and relayer
archival against the local Walrus. Sections 1–5 were learned on devstack **0.1.1**; section 9 covers
the **0.7.0** migration (which supersedes parts of 1, 2, 3, 5 — noted inline); section 10 covers
local Walrus.

**Upstream docs (not vendored — read on GitHub):**

- devstack: <https://github.com/MystenLabs/ts-sdks-incubation/tree/main/packages/docs/content/devstack>
  (rendered: <https://ts-sdks-incubation.vercel.app/devstack>)
- dev-wallet: <https://github.com/MystenLabs/ts-sdks-incubation/tree/main/packages/docs/content/dev-wallet>
  (rendered: <https://ts-sdks-incubation.vercel.app/dev-wallet>)

The integration itself (config + app wiring) is documented in
[`chat-app/docs/DEVSTACK.md`](../../../../chat-app/docs/DEVSTACK.md). This file is the friction log.

---

## 1. Publishing `sui_stack_messaging` (which depends on published `sui_groups`) — the hard one

`localPackage()` builds **offline** with a hardcoded env
(`sui move build -e testnet … --with-unpublished-dependencies`) then a **single**
`Transaction.publish({ modules, dependencies })`.

- `--with-unpublished-dependencies` is the `--publish-unpublished-deps` equivalent: **unpublished**
  transitive deps get their bytecode bundled. `suins` (the pinned rev ships no `Published.toml`)
  bundles cleanly.
- `sui_groups` ships a committed `Published.toml` with `[published.testnet]`, so the `-e testnet`
  build resolves it to that on-chain **testnet** id and *links* against it instead of bundling →
  publish to localnet fails: `PublishError`/`publish-tx` "Dependent package not found on-chain:
  0xba8a…". `-e testnet` is harmless for normal local packages (nothing resolves); it only bites a
  dep genuinely published on testnet.
- **Single `Transaction.publish({ modules })` MERGES all bundled modules into ONE package.** So on
  localnet, messaging + sui_groups + suins land at **one shared package id** — i.e.
  `permissionedGroups` id == messaging id. The SDK works because `permissioned_group`,
  `messaging`, `version` all live in that one package.

The localnet test path (`ts-sdks/.../test/helpers/localnet`) avoids the linking problem because
`sui client test-publish` reconciles published-status against the **live localnet chain-id** (where
sui_groups is unpublished → bundled). devstack's offline `-e testnet` build can't, and there's no
build-env option. `knownPackage(...)` is for deps already on-chain on the target network — not our
fresh-local-publish case.

**Our fix** (`chat-app/devstack.config.ts`): materialize gitignored copies under `chat-app/.devstack/`
(canonical package untouched) that look **unpublished** to the `-e testnet` build —

- clone `sui_groups` at the pinned rev, **strip its `Published.toml` + `Move.lock`**, point
  messaging's `Move.toml` at it via `{ local = … }` (devstack copies local deps into its build
  scratch; git deps keep their `Published.toml`);
- patch messaging's `suins` MVR dep → git (MVR doesn't resolve on localnet);
- strip messaging's own `Published.toml` so it publishes fresh.

Still required on 0.7.0: devstack now auto-scrubs `Move.lock` `[pinned.*]`/`[env]` sections (build
tree AND the `~/.move/git` cache) but **never touches `Published.toml`** — the copies stay.

**Superseded by 0.7.0:** the app no longer recovers namespace/version/groups from the publish tx via
GraphQL. `localPackage`'s `capture` option grabs the created singletons by type suffix
(`::messaging::MessagingNamespace`, `::version::Version`) and codegen surfaces them as
`packages.sui_stack_messaging.objects`; the groups id is the merged package id by construction.

## 2. Seal — one local key server, threshold 1

On 0.1.1, two local-keygen servers **failed codegen** (`CodegenEmitterCollision` — per-instance
`seal/<name>.ts` bindings collided) and racing registrations on one signer threw
`SealError`/`register` "object … unavailable for consumption". 0.7.0 fixes the collision structurally
(one keyed `seal.ts` bucket; the Seal Move publish never enters the bindings emitter), so multiple
servers are possible now. We keep **one** server (its own signer, off `publisher`, so it never races
the messaging publish) as a lightweight choice, and the app sets `encryption.sealThreshold: 1` (SDK
default is 2 = testnet two-server topology). `serverConfigs` comes from the generated `seal` module.

## 3. Dev-wallet — now injected by the Vite plugin (0.2.0+)

**Superseded:** on 0.1.1, `devstackVitePlugin()` only aliased `@generated`, and the app had to build a
`DevstackSignerAdapter` from `@generated/dapp-kit/config` and register it via
`devWalletInitializer({ mountUI: true })` in `createDAppKit({ walletInitializers })`. Since 0.2.0 the
plugin **injects and registers** the dev wallet on the page itself (wallet-standard auto-discovery;
the pairing token moved out of codegen into a 0o600 side-channel the plugin reads), and
`@generated/dapp-kit/config` no longer exists — the chat-app dropped its
`@mysten-incubation/dev-wallet` devDependency entirely. Two behaviors to know:

- **No auto-connect** (0.2.0 removed storage-seeded auto-connect): a fresh page loads disconnected and
  a human clicks Connect; e2e drives connection via `registerDAppKitForTesting` +
  Playwright `connectAs` (the chat-app registers the bridge in dev).
- **The DevWallet still allows only one pending sign** → concurrent session-key + tx signs throw "a
  signing request is already pending". Real wallets queue; the DevWallet doesn't, and dApp Kit doesn't
  queue either. Fix stays: serialize sign calls app-side — the chat-app subclasses
  `CurrentAccountSigner` with a promise chain around `signPersonalMessage`
  (`src/lib/queued-signer.ts`). React StrictMode double-render makes the race more likely.

## 4. Relayer on devstack — use the host-published port, not the routed one

devstack does not run the reference relayer. Run it separately (host process / `cargo run`, so it can
reach the node), with `GROUPS_PACKAGE_ID` = the **merged** package id and `SUI_RPC_URL` = the
**direct, host-published validator port**, NOT the Traefik-routed `:9000`. The router fronts `:9000`
as HTTP/1 (JSON-RPC works), but the relayer's gRPC checkpoint subscription gets `HTTP 400`
("grpc-status header missing") through it. The validator host-publishes its `:9000` on a dynamic high
port — find it with `docker port <validator-container> 9000` (e.g. `127.0.0.1:51000`) and point the
relayer there. Then `Subscribed to checkpoint stream` succeeds and membership sync works.
(Docker-Compose relayer instead → `host.docker.internal:<port>` or join the devstack network.)

The merged package id now lives in the deployment envelope:
`packages.sui_stack_messaging.id` in `chat-app/.devstack/stacks/chat-app-local/deployment.json`
(the 0.1.1 `src/generated/packages.ts` is gone).

## 5. GraphQL is the newer schema

The devstack local GraphQL is a newer Sui GraphQL than testnet: endpoint is **`/graphql`** (the
generated `graphql` URL has no path — append it), and it uses **`transaction(digest:)`** /
**`object{ previousTransaction }`** (not `transactionBlock` / `previousTransactionBlock`). The
bootstrap-recovery code that needed this is gone (capture, §1), but group discovery
(`useGroupDiscovery`'s `events(filter: { type })` pagination) still runs against it on localnet —
untested there so far; if it breaks, this schema gap is the first suspect.

## 6. Errors → fixes (quick index)

| Tag / symptom | Cause | Fix |
|---|---|---|
| `PublishError`/`publish-tx` "Dependent package not found" | sui_groups linked at its testnet id | strip `Published.toml`, bundle as local (§1) |
| `PublishError`/`publish-tx` "fetch failed" (both publishes) | localnet RPC wedged after many reconciles | `devstack wipe --yes` + `docker rm -f $(docker ps -aq --filter name=devstack)`, fresh `up` |
| `SealError`/`register` "object … unavailable" | two seal servers on one signer | dedicated signer per server (§2) |
| `CodegenEmitterCollision` | 0.1.1 per-instance seal bindings | fixed in 0.7.0; historical (§2) |
| `HostServiceAcquireError`/`exit` (`ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`) | `pnpm exec vite` hit pnpm-v11 deps-purge in a non-TTY child | run vite via `node_modules/.bin/vite` in the host-service `script` |
| "A signing request is already pending" | DevWallet one-pending-sign + concurrent signs | queued `CurrentAccountSigner` subclass (§3) |
| relayer "grpc-status header missing, HTTP 400" | gRPC through Traefik | point at the host-published validator port (§4) |
| package member restart-loops every ~5s after `devstack apply` | identity option (e.g. `mvrPlaceholder`) changed on a live stack; cache-hit publish can't adopt it, drift detector keeps restarting | don't change `localPackage` identity options live; `devstack wipe --yes` + fresh `up` (§9) |
| `@generated` import throws `loadDeployment` error outside devstack | 0.7.0 stubs resolve through the injected envelope | keep `@generated` behind the devstack-gated shim (§9) |

## 7. Operational

- **Node >= 24** (devstack `engines`; `nvm install 24`). **Docker** running. A host **`sui` CLI** is
  required for `devstack codegen` (Docker fallback removed in 0.3.0). First boot pulls/builds images —
  the Walrus image build dominates (release binaries; cached after).
- **pnpm v11** purges node_modules on a v10 lockfile/config mismatch (same root cause as the
  host-service crash). Install with `npx pnpm@10 install`, or move pnpm settings into
  `pnpm-workspace.yaml` and `CI=true pnpm install`. The chat-app's `minimumReleaseAge` policy (enforced
  by pnpm v11) blocks devstack's <2-day-old transitive deps — a separate supply-chain gate that keeps
  the chat-app on a pnpm-10 lockfile for now.
- Logs: `devstack up --renderer plain`. Reset: `devstack wipe --yes`. `devstack prune --yes` only
  removes *idle* groups (a live validator isn't idle). Re-emit codegen: `devstack apply`.

## 8. dapp-kit migration (done)

The chat-app runs on `@mysten/dapp-kit-react` (sui-2.0, gRPC-native): `createDAppKit` +
`DAppKitProvider`, `useCurrentClient()` as the base client source, imperative
`dAppKit.signAndExecuteTransaction` / `signPersonalMessage` (no mutation hooks). The dev wallet
arrives via the devstack Vite plugin (§3), not `walletInitializers`. The sign-request serialization
stays — dApp Kit does not queue wallet requests and the DevWallet still allows only one pending sign.
Guide used: <https://sdk.mystenlabs.com/sui/migrations/sui-2.0/llms.txt>.

## 9. devstack 0.1.1 → 0.7.0 migration (done)

The codegen model inverted: `src/generated/` is now **id-free stubs**
(`config.ts`/`seal.ts`/`walrus.ts`/`config-runtime.ts`/`deployment.ts`) — committable by design
upstream, though this repo keeps them gitignored and regenerated per `devstack up` — that resolve
through a deployment envelope — `__DEVSTACK_DEPLOYMENT__`, injected by `devstackVitePlugin()` at dev/build time
(`DEVSTACK_DEPLOYMENT_FILE` is the Node fallback). Everything the app reads goes through
`config.forNetwork(net)` (`{ rpc, graphql, packages: { <name>: { id, objects } }, mvrOverrides,
values }`). What bit us:

- **Old module paths are gone** (`seal/local`, `packages`, `sui/network`, `dapp-kit/config`,
  `services`, `extras`) — the shim now imports `config`/`seal`/`walrus` and resolves for
  `config.defaultNetwork`. Field renames: `rpcUrl→rpc`, `graphqlUrl→graphql`, network key
  `local→localnet`.
- **Evaluating `@generated` without an envelope throws** — the dev-only virtual-module gate is still
  the right seam, for a new reason (the stubs are prod-safe by design but resolve to errors without a
  deployment).
- **`codegen.outputDir` was removed** from `defineDevstack` (silently — no changelog line); output is
  hardcoded to `<appRoot>/src/generated`.
- **`mvrPlaceholder` is normalized under `@local/`** — it cannot carry arbitrary names like
  `@local-pkg/sui-stack-messaging` (it slugifies to `@local/local-pkg-sui-stack-messaging`). The SDK's
  MVR names stay hand-mapped in `devstack-config.ts`.
- **Changing identity options on a live stack restart-loops the reconciler** (cache-hit publish keeps
  the old record; drift never converges; the `after`-dependent app restarts with it, every ~5s). Wipe
  and boot fresh. Probably worth an upstream issue.
- **Upgrade requires `devstack wipe`** (0.2.0 chain→network rename invalidates on-disk state) and a
  `docker rm -f` of any stale devstack containers (postgres sidecar password derivation changed).
- Deterministic genesis + name-derived accounts mean a wipe + fresh boot can reproduce the **same**
  chain id and package id — don't read "same id" as "state survived".
- `sui()` now boots a GraphQL-indexer Postgres sidecar **by default** (`indexer: false` opts out) and
  resumes chain DBs across container restarts; `devstack up --warm` caches boots.
- **dapp-kit versions must track devstack's catalog.** The injected dev wallet registers through
  dapp-kit's wallet-initializer handshake; on dapp-kit-core 1.3.x it fails with a single console line
  (`Skipping wallet initializer: "Error: Registration un-successful."`) and the wallet silently never
  appears in the connect modal — while the floating panel still mounts, which misdirects debugging.
  devstack 0.7.0 targets `@mysten/dapp-kit-core ^1.6.0` / `@mysten/dapp-kit-react ^2.1.2`; keep the
  chat-app pins at or above those.

## 10. Local Walrus (0.6.0/0.7.0) — attachments + archival fully local (done)

`walrus()` (bare) boots storage node(s) **plus the release publisher, aggregator, and upload-relay
containers — all on by default**. Validated end-to-end here: chat-app attachment upload via
`PUT {publisher}/v1/quilts`, download via `GET {aggregator}/v1/blobs/by-quilt-patch-id/…`, and relayer
quilt archival with the indexer tag contract intact (`source=sui-messaging-relayer`, `group_id`,
`sender`, `sync_status`, `order` — checked via `GET /v1/quilts/<blobId>/patches`).

- **URLs** are Traefik-routed on the fixed shared port 9185:
  `http://walrus-{publisher,aggregator,upload-relay}.<stack>.<app>.localhost:9185`, emitted in the
  generated `walrus` bindings (`publisherUrl`/`aggregatorUrl`/`uploadRelayUrl`).
- **Host processes reach them as-is** — macOS resolves `*.localhost` to loopback (curl, Node, and the
  relayer's reqwest all verified live); the router listens on `127.0.0.1:9185` and dispatches by
  `Host` header. No `--add-host`, no published per-service ports. (gRPC remains the exception — §4.)
- **Nobody but the publisher needs WAL.** The walrus-deploy one-shot creates and funds the shared
  client wallet (default 10 SUI, `WALRUS_CLIENT_WALLET_SUI_AMOUNT_MIST` to override); the publisher
  pays for storage on every unauthenticated `PUT`. Browser wallets hold zero WAL for attachments.
  `walCoin()` is only needed if an *account* writes blobs via the `@mysten/walrus` SDK signing path
  (it swaps that account's own SUI at the local exchange).
- **The upload relay is unused** by the messaging SDK's `WalrusHttpStorageAdapter` (publisher HTTP
  path). It's there (with `tip_config: !no_tip`) for `@mysten/walrus` SDK upload flows — relevant to
  the `configure-walrus-storage-via-sdk` skill on localnet.
- **Committee reachability was solved upstream** (the June research blocker): committee addresses are
  plain Docker-DNS aliases (`dryrun-node-<i>`) on the per-stack walrus network, and the client-service
  containers join that network. The `.localhost` per-node routes are diagnostics only.
- **Local epoch duration defaults to 24h** (`walrus({ local: { epochDuration } })` to change — note it
  is part of the deploy cache key, so changing it forces a fresh Walrus deploy with new ids, orphaning
  stored blobs). Relayer dev loop: `WALRUS_STORAGE_EPOCHS=1`, `WALRUS_SYNC_INTERVAL_SECS=15`,
  `WALRUS_SYNC_MESSAGE_THRESHOLD=1`.
- **Relayer archival cannot be disabled, only repointed** — on localnet, leaving
  `WALRUS_PUBLISHER_URL` at its default silently ships (encrypted) message JSON to the public testnet
  publisher. Repoint it (§4 env block in the skill).

The `walrus-discovery-indexer` runs against the local stack (SEW-1004 tier 2b, validated live:
e2e message → relayer quilt → BlobCertified → discovery → REST): `NETWORK=localnet` +
`SUI_GRPC_URL` (direct validator port, same gRPC-through-Traefik caveat as the relayer) +
`WALRUS_PACKAGE_ID`/`WALRUS_AGGREGATOR_URL` from the envelope — all extracted by
`chat-app/scripts/local-indexer.sh`. On localnet blob inspection goes through the aggregator's
`/v1/quilts/{id}/patches` HTTP API instead of the `@mysten/walrus` SDK: the SDK reads quilt indexes
from the storage nodes at their committee-advertised addresses (`dryrun-node-<i>` Docker-DNS
aliases), which don't resolve from a host process.

Tier 2c done too: the chat-app carries a `WalrusRecoveryTransport`
(`src/lib/walrus-recovery-transport.ts`, adapted from the SDK's non-exported example) wired via the
factory's `recovery` option + a **Restore** button in the chat header (validated live: 2 messages
archived → relayer-independent recovery, decrypted + sender-verified). One SDK bug found on the way:
the relayer archives `signature`/`public_key` as Rust `Vec<u8>` number arrays, but
`fromWalrusMessage` (<= 0.0.2) passed them through verbatim while verification expects hex strings →
`senderVerified: false` on every recovered message. Fixed in the SDK (with changeset); the chat-app
transport normalizes the fields itself until that release ships.
