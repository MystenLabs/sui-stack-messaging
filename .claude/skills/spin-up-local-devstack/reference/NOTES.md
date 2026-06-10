# devstack + dev-wallet notes for the sui-stack-messaging chat-app

What we learned wiring `@mysten-incubation/devstack@0.1.1` + `@mysten-incubation/dev-wallet@0.3.0`
into the chat-app for a **fully-local, end-to-end-encrypted** stack (local Sui + local-keygen Seal +
published package + dev-wallet), verified `create → send → DECRYPT` locally.

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
(`sui move build -e testnet … --with-unpublished-dependencies`, in
`devstack/dist/substrate/runtime/sui-move-build/index.mjs`) then a **single**
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

`config.packages` only carries the merged messaging id; namespace/version singletons and the
`sui_groups`/`permissioned_group` id are **not** surfaced. The app recovers them from the publish tx
at bootstrap via GraphQL (see §5) — `chat-app/src/lib/devstack-config.ts`.

## 2. Seal — one local key server, threshold 1

The docs only ever show one `seal({ mode: 'local-keygen', signer })`. Trying **two** local-keygen
servers:

- **boots** only if each uses a **distinct signer** (two registrations on one signer race that
  account's gas coin → `SealError`/`register` "object … unavailable for consumption");
- then **fails codegen** — both publish a Seal Move package, codegen emits a package binding per
  package, the two "seal" packages collide → `CodegenEmitterCollision`, supervisor aborts. Structural
  in 0.1.1; no `excludeFromCodegen` on `seal()`.

**Our fix:** one local-keygen Seal server (its own signer, off `publisher`, so it never races the
messaging publish), and the app sets `encryption.sealThreshold: 1` (SDK default is 2 = testnet
two-server topology). `serverConfigs` comes from `@generated/seal/local.ts`.

## 3. Dev-wallet — devstack does NOT register it; the app must

`devstackVitePlugin()` in 0.1.1 does exactly **one** thing: alias `@generated` to the codegen dir
(`devstack/dist/build-integrations/vite/index.mjs`). It does **not** inject a wallet. devstack's
`wallet({ accounts })` runs a server (`http://…:6173`, funded accounts, keys stay server-side; signs
over `/api/v1/devstack/*`) and emits `@generated/dapp-kit/config.ts` (`walletUrl`, `pairUrl#token`,
`chain: sui:local` — sensitive, gitignored). The browser app wires it up itself:

```ts
import { DevWallet } from '@mysten-incubation/dev-wallet';
import { DevstackSignerAdapter, parseDevstackToken } from '@mysten-incubation/dev-wallet/adapters';
import { mountDevWallet } from '@mysten-incubation/dev-wallet/ui';
const a = new DevstackSignerAdapter({ serverOrigin: dappKitConfig.walletUrl, token: parseDevstackToken(dappKitConfig.pairUrl) });
await a.initialize();                       // fetch the funded accounts from the server
const w = new DevWallet({ adapters: [a], networks: { localnet: suiNetwork.rpcUrl } });
w.register();                               // wallet-standard -> dapp-kit's ConnectButton lists it
mountDevWallet(w);                          // floating panel = where connect/sign approvals happen
```

Gotchas hit:
- **`DevWalletClient` (popup) is the wrong client** — that's for a standalone served wallet UI; the
  devstack server is an HTTP signing API, consumed via `DevstackSignerAdapter`.
- **`createDevstackAdapterFromManifest` wants the nested runtime `Manifest`**, not the flat generated
  `dappKitConfig` — use `DevstackSignerAdapter` + `parseDevstackToken` directly.
- **Without `mountDevWallet`, connect hangs** at "Confirm connection in the wallet" — no UI to confirm in.
- **The DevWallet allows only one pending sign** → concurrent session-key + tx signs throw "a signing
  request is already pending" (`dev-wallet/dist/wallet/dev-wallet.mjs`). Real wallets queue; the
  DevWallet doesn't. Fix: serialize sign calls app-side (a promise chain around `signPersonalMessage`
  in `MessagingClientContext.tsx`). React StrictMode double-render makes the race more likely.

## 4. Relayer on devstack — use the host-published port, not the routed one

devstack does not run the reference relayer. Run it separately (host process / `cargo run`, so it can
reach the node), with `GROUPS_PACKAGE_ID` = the **merged** package id and `SUI_RPC_URL` = the
**direct, host-published validator port**, NOT the Traefik-routed `:9000`. The router fronts `:9000`
as HTTP/1 (JSON-RPC works), but the relayer's gRPC checkpoint subscription gets `HTTP 400`
("grpc-status header missing") through it. The validator host-publishes its `:9000` on a dynamic high
port — find it with `docker port <validator-container> 9000` (e.g. `127.0.0.1:51000`) and point the
relayer there. Then `Subscribed to checkpoint stream` succeeds and membership sync works.
(Docker-Compose relayer instead → `host.docker.internal:<port>` or join the devstack network.)

## 5. GraphQL is the newer schema

The devstack local GraphQL is a newer Sui GraphQL than testnet: endpoint is **`/graphql`** (the
generated `graphqlUrl` has no path — append it), and it uses **`transaction(digest:)`** /
**`object{ previousTransaction }`** (not `transactionBlock` / `previousTransactionBlock`). The
bootstrap recovery (`devstack-config.ts`) reads the messaging publish tx's `effects.objectChanges`:
created MoveObjects matched by type (`MessagingNamespace`, `::version::Version`) and the MovePackage
exposing the `permissioned_group` module (= the merged messaging id). Group discovery (testnet-shaped
queries) may need the same schema port if exercised on localnet.

## 6. Errors → fixes (quick index)

| Tag / symptom | Cause | Fix |
|---|---|---|
| `PublishError`/`publish-tx` "Dependent package not found" | sui_groups linked at its testnet id | strip `Published.toml`, bundle as local (§1) |
| `PublishError`/`publish-tx` "fetch failed" (both publishes) | localnet RPC wedged after many reconciles | `devstack wipe --yes` + `docker rm -f $(docker ps -aq --filter name=devstack)`, fresh `up` |
| `SealError`/`register` "object … unavailable" | two seal servers on one signer | one server, dedicated signer (§2) |
| `CodegenEmitterCollision` | two Seal package bindings | one Seal server (§2) |
| `HostServiceAcquireError`/`exit` (`ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`) | `pnpm exec vite` hit pnpm-v11 deps-purge in a non-TTY child | run vite via `node_modules/.bin/vite` in the host-service `script` |
| connect hangs "Confirm connection in the wallet" | no wallet UI mounted | `mountDevWallet(wallet)` (§3) |
| "A signing request is already pending" | DevWallet one-pending-sign + concurrent signs | serialize signs app-side (§3) |
| relayer "grpc-status header missing, HTTP 400" | gRPC through Traefik | point at the host-published validator port (§4) |

## 7. Operational

- **Node >= 24** (devstack `engines`; `nvm install 24`). **Docker** running. First boot pulls images (slow).
- **pnpm v11** purges node_modules on a v10 lockfile/config mismatch (same root cause as the
  host-service crash). Install with `npx pnpm@10 install`, or move pnpm settings into
  `pnpm-workspace.yaml` and `CI=true pnpm install`. The chat-app's `minimumReleaseAge` policy (enforced
  by pnpm v11) blocks devstack's <2-day-old transitive deps — a separate supply-chain gate that keeps
  the chat-app on a pnpm-10 lockfile for now.
- Logs: `devstack up --renderer plain`. Reset: `devstack wipe --yes`. `devstack prune --yes` only
  removes *idle* groups (a live validator isn't idle). Re-emit codegen: `devstack apply`.

## 8. Follow-up: migrate the chat-app to `@mysten/dapp-kit-react`

The chat-app is on the **deprecated** `@mysten/dapp-kit` (JSON-RPC-only, never gets gRPC/GraphQL).
`@mysten/dapp-kit-react` (sui-2.0) is the path forward and is gRPC-native. Browser-gRPC-on-localnet is
**proven working** here (the messaging base client is already `SuiGrpcClient`), so the migration's main
unknown is retired. The dev-wallet wiring is identical on both stacks (same `DevstackSignerAdapter`),
so migration is a separate, deliberate PR — see the cost-benefit (workaround-now / migrate-next).
Guide: <https://sdk.mystenlabs.com/sui/migrations/sui-2.0/llms.txt>.
