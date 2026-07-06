// All-local dev stack for the chat-app via @mysten-incubation/devstack.
//
// Composes a local Sui node + a LOCAL Seal key server (`seal({ mode:
// 'local-keygen' })`) + a LOCAL Walrus cluster (storage nodes + publisher +
// aggregator + upload relay) + the messaging Move package + a browser dev
// wallet + the Vite dev server, and writes id-free typed config stubs to
// `src/generated/` (values resolve at dev/build time through the deployment
// envelope the devstack Vite plugin injects). The local Seal key server is
// the point: it BLS-keygens a master key, publishes the Seal Move package to
// the in-stack node, registers an on-chain KeyServer bound to the in-stack
// RPC, and serves it — so message decryption works fully locally (the testnet
// key servers cannot authorize localnet group objects). Local Walrus closes
// the remaining seam: attachments and relayer archival no longer touch
// testnet.
//
// Requirements: Docker, Node >= 24 (devstack `engines`), a host `sui` CLI for
// `devstack codegen`. Images are fetched/built on first boot. Keep
// `@mysten-incubation/devstack` a chat-app devDependency only — never a
// dependency of the canonical SDK.
//
// Run:
//   pnpm devstack up        # attached supervisor: sui + Seal + Walrus + publish + serve
//   pnpm devstack apply     # reconcile through a live supervisor, or one-shot
//
// Upgrading from devstack <= 0.1.x: run `devstack wipe` once (the 0.2.0
// chain -> network rename invalidates on-disk stack state).

import { execFileSync } from 'node:child_process';
import { cpSync, existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
	account,
	defineDevstack,
	HOST_SERVICE_PORT_TOKEN,
	hostService,
	localPackage,
	seal,
	sui,
	wallet,
	walrus,
} from '@mysten-incubation/devstack';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..');
const DEV_PORT = 5173;

// --- Patched build sources (the one risky bit) ------------------------------
// `localPackage()` builds from `sourcePath` with `sui move build -e testnet …
// --with-unpublished-dependencies` (the `-e testnet` is hardcoded in devstack
// 0.7.0), then publishes in one tx. `--with-unpublished-dependencies` bundles
// *unpublished* transitive deps into that single publish. The catch: a dep
// that ships a committed `Published.toml` with a `[published.testnet]` entry
// (here, `sui_groups`) is resolved by the `-e testnet` build to its on-chain
// testnet id and *linked* rather than bundled — and that id doesn't exist on
// localnet, so the publish fails ("Dependent package not found on-chain").
// devstack scrubs `[pinned.*]`/`[env]` sections out of every Move.lock in the
// build tree automatically (0.7.0), but it never touches `Published.toml`, so
// we still pre-stage COPIES (canonical package untouched):
//   - `suins = { r.mvr = "@suins/core" }`  ->  a LOCAL copy (MVR doesn't
//     resolve on localnet). Its committed Move.lock is scrubbed by devstack
//     now; we strip it anyway for a belt-and-braces unpublished tree.
//   - `sui_groups`  ->  a LOCAL copy with `Published.toml`/`Move.lock`
//     stripped, so the `-e testnet` build treats it as unpublished and
//     bundles it.
//   - drop messaging's own `Published.toml`/`Move.lock` so it publishes fresh
//     on localnet.
const CANONICAL_MESSAGING = resolve(REPO_ROOT, 'move/packages/sui_stack_messaging');
const PATCHED_ROOT = resolve(HERE, '.devstack');
const PATCHED_MESSAGING = resolve(PATCHED_ROOT, 'sui_stack_messaging');
const PATCHED_GROUPS = resolve(PATCHED_ROOT, 'sui_groups'); // git checkout root
const PATCHED_GROUPS_PKG = resolve(PATCHED_GROUPS, 'move/packages/sui_groups');
const PATCHED_SUINS = resolve(PATCHED_ROOT, 'suins'); // git checkout root
const PATCHED_SUINS_PKG = resolve(PATCHED_SUINS, 'packages/suins');

// Matches the `sui_groups` git rev pinned in the canonical messaging Move.toml.
const SUI_GROUPS_GIT = 'https://github.com/MystenLabs/sui-groups.git';
const SUI_GROUPS_REV = 'ea766818b90e162341e885a855718388edcc8e99';
const SUINS_GIT = 'https://github.com/MystenLabs/suins-contracts.git';
const SUINS_REV = '2b75990bdc31472405a6bf47b40152627a1fa6c0';
const SUINS_DEP = 'suins = { local = "../suins/packages/suins" }';

// Strip committed published addresses + lockfile so the `-e testnet` build treats a
// package as UNPUBLISHED on localnet and bundles it.
function stripPublished(pkgDir: string) {
	rmSync(resolve(pkgDir, 'Published.toml'), { force: true });
	rmSync(resolve(pkgDir, 'Move.lock'), { force: true });
}

// Reuse a cached checkout only if it sits at the pinned rev — otherwise a rev
// bump would silently keep publishing the stale cache.
function materializeGitCheckout(checkoutRoot: string, pkgDir: string, url: string, rev: string) {
	const atPinnedRev = () => {
		try {
			return (
				execFileSync('git', ['-C', checkoutRoot, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim() ===
				rev
			);
		} catch {
			return false;
		}
	};
	if (!existsSync(resolve(pkgDir, 'Move.toml')) || !atPinnedRev()) {
		rmSync(checkoutRoot, { recursive: true, force: true });
		execFileSync('git', ['clone', '--quiet', url, checkoutRoot], { stdio: 'inherit' });
		execFileSync('git', ['-C', checkoutRoot, 'checkout', '--quiet', rev], { stdio: 'inherit' });
	}
	stripPublished(pkgDir);
}

// Rewrite a dependency line, failing loudly if the canonical Move.toml no longer
// matches the pattern — a silent no-op would surface much later as an obscure
// MVR-resolution / "Dependent package not found on-chain" publish error.
function replaceDep(toml: string, pattern: string | RegExp, replacement: string): string {
	const out = toml.replace(pattern, replacement);
	if (out === toml) {
		throw new Error(
			`devstack.config.ts: Move.toml patch pattern ${String(pattern)} matched nothing — ` +
				`the canonical sui_stack_messaging Move.toml changed shape; update the patterns.`,
		);
	}
	return out;
}

function materializeMessaging() {
	rmSync(PATCHED_MESSAGING, { recursive: true, force: true });
	cpSync(CANONICAL_MESSAGING, PATCHED_MESSAGING, {
		recursive: true,
		// Skip build artifacts and the pinned lockfile — sui move build regenerates them.
		filter: (src) => !/[/\\]build([/\\]|$)/.test(src) && !/[/\\]Move\.lock$/.test(src),
	});
	const tomlPath = resolve(PATCHED_MESSAGING, 'Move.toml');
	let toml = readFileSync(tomlPath, 'utf8');
	toml = replaceDep(toml, 'suins = { r.mvr = "@suins/core" }', SUINS_DEP);
	toml = replaceDep(
		toml,
		/^sui_groups = \{ git =.*$/m,
		'sui_groups = { local = "../sui_groups/move/packages/sui_groups" }',
	);
	writeFileSync(tomlPath, toml);
	stripPublished(PATCHED_MESSAGING);
}

materializeGitCheckout(PATCHED_GROUPS, PATCHED_GROUPS_PKG, SUI_GROUPS_GIT, SUI_GROUPS_REV);
materializeGitCheckout(PATCHED_SUINS, PATCHED_SUINS_PKG, SUINS_GIT, SUINS_REV);
materializeMessaging();

// --- Network + accounts -----------------------------------------------------
export const localnet = sui(); // in-stack Sui validator + faucet + GraphQL (Docker)
export const publisher = account('publisher'); // publishes Move packages
// Dedicated signer for the Seal key server (kept off `publisher` so the seal
// registration never races the messaging publish on the same gas coin).
export const sealSigner = account('seal_keygen');
export const alice = account('alice');
export const bob = account('bob');

// --- Local Seal key server (the whole point) --------------------------------
// One local-keygen key server: it BLS-keygens a master key, publishes the Seal
// Move package, registers an on-chain KeyServer bound to the in-stack RPC, and
// serves it. One server is a deliberate lightweight choice — the app matches it
// with `sealThreshold: 1`. Codegen folds all seal instances into a single
// `src/generated/seal.ts` bucket keyed by name; `serverConfigs`
// (`[{ objectId, weight }]`) is SDK-ready for `new SealClient`.
export const keyServer = seal({ mode: 'local-keygen', signer: sealSigner, name: 'local' });

// --- Local Walrus (attachments + relayer archival) ---------------------------
// Boots a local Walrus cluster: deploys the wal + walrus Move packages, stands
// up an ACTIVE on-chain committee of storage nodes, and starts the release
// publisher, aggregator, and upload-relay client services (all on by default
// since devstack 0.6/0.7). The publisher's wallet is created and funded by the
// walrus-deploy one-shot, so browser accounts need no WAL for attachment
// upload — the publisher pays. `publisherUrl`/`aggregatorUrl` land in the
// generated walrus bindings and flow into the app via the vite shim; point the
// relayer's WALRUS_PUBLISHER_URL at the same publisher for fully-local
// archival (see the Relayer note below).
export const blobs = walrus();

// --- Move packages ----------------------------------------------------------
// One bundled publish (sui_groups + suins + messaging in a single tx, merged
// into ONE package id on localnet). `capture` surfaces the two shared
// singletons the SDK's `packageConfig.messaging` needs (MessagingNamespace +
// Version) as `packages.sui_stack_messaging.objects` in the generated config;
// the bundled `sui_groups` id IS the merged package id. The MVR names the SDK
// bindings resolve through (`@local-pkg/…`) are mapped by hand in
// `src/lib/devstack-config.ts` — devstack's own placeholder is always
// normalized under `@local/`, so it can't carry them.
export const messaging = localPackage('sui_stack_messaging', {
	sourcePath: PATCHED_MESSAGING,
	publisher,
	capture: {
		namespaceId: '::messaging::MessagingNamespace',
		versionId: '::version::Version',
	},
});

// --- Dev wallet (browser) ---------------------------------------------------
// The devstack Vite plugin injects and registers the dev wallet on the page in
// dev (wallet-standard auto-discovery — dapp-kit's ConnectButton lists it; no
// app-side initializer code). Accounts are pre-funded; keys stay server-side.
export const devWallet = wallet({ accounts: [publisher, alice, bob] });

// --- The chat-app dev server ------------------------------------------------
export const app = hostService({
	name: 'chat-app',
	// Run vite via the local bin (not `pnpm exec`) so the host-service child never
	// triggers pnpm's pre-exec deps-status check, which on pnpm v11 tries to purge
	// node_modules in a non-TTY child and kills the service.
	script: `node_modules/.bin/vite --host 127.0.0.1 --strictPort --port ${HOST_SERVICE_PORT_TOKEN}`,
	cwd: HERE,
	port: DEV_PORT,
	ready: { kind: 'http' },
	// Wait for chain, key server, Walrus, package publish, and wallet before serving.
	after: [messaging, keyServer, devWallet, blobs] as const,
});

export default defineDevstack({
	members: [localnet, keyServer, blobs, messaging, devWallet, app],
	stackName: 'chat-app-local',
});

// --- Relayer ----------------------------------------------------------------
// devstack does NOT run the reference relayer, but the SDK send/fetch path goes
// through it. Run it separately (host process) pointed at the DIRECT host-published
// validator port — `docker port <sui-validator> 9000` — NOT the Traefik-routed :9000
// (the relayer's gRPC checkpoint subscription 400s through the router). `GROUPS_PACKAGE_ID`
// = the locally-published package id (from the generated config / deployment envelope),
// `SUI_RPC_URL` = that host-published port. The chat-app reads `VITE_RELAYER_URL`
// (default http://localhost:3000).
//
// Walrus archival: also set WALRUS_PUBLISHER_URL / WALRUS_AGGREGATOR_URL to the
// local daemons — for this stack:
//   http://walrus-publisher.chat-app-local.chat-app.localhost:9185
//   http://walrus-aggregator.chat-app-local.chat-app.localhost:9185
// (the routed URLs from the generated walrus bindings) — otherwise the relayer
// archives localnet messages to the PUBLIC testnet publisher (its default). For
// a fast archival dev loop, lower WALRUS_SYNC_INTERVAL_SECS (default 3600),
// WALRUS_SYNC_MESSAGE_THRESHOLD (default 50), and WALRUS_STORAGE_EPOCHS (default 5).

// --- How the app consumes the generated output ------------------------------
// devstack codegen writes id-free stubs to `src/generated/` (gitignored here,
// regenerated on every `devstack up`): every value resolves at dev/build time
// through the `__DEVSTACK_DEPLOYMENT__` envelope the devstack Vite plugin
// injects (`devstack codegen` needs a host `sui` CLI).
// The app reads the generated modules through a `virtual:devstack-app-config`
// shim (so non-devstack builds never import `@generated`) + `src/lib/devstack-config.ts`:
//   @generated/config  -> per-network entry (rpc, graphql, packages incl. captured
//                         namespace/version ids, mvrOverrides)
//   @generated/seal    -> SealClient serverConfigs (threshold 1)
//   @generated/walrus  -> publisherUrl/aggregatorUrl for the attachments adapter
// The dev wallet is injected by the Vite plugin itself (no generated module).
//
// Node tooling (not the browser) can read the runtime manifest via
// `@mysten-incubation/devstack/runtime` (`readStackContext`); the browser path is
// the generated imports.
