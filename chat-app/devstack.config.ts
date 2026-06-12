// All-local dev stack for the chat-app via @mysten-incubation/devstack.
//
// Composes a local Sui node + a LOCAL Seal key server (`seal({ mode:
// 'local-keygen' })`) + the messaging Move package + a browser dev wallet + the
// Vite dev server, and writes typed config to `src/generated/`. The local Seal
// key server is the point: it BLS-keygens a master key, publishes the Seal Move
// package to the in-stack node, registers an on-chain KeyServer bound to the
// in-stack RPC, and serves it — so message decryption works fully locally
// (the testnet key servers cannot authorize localnet group objects).
//
// Requirements: Docker, Node >= 24 (devstack `engines`). The Seal key-server
// image is fetched on first boot. Keep `@mysten-incubation/devstack` a chat-app
// devDependency only — never a dependency of the canonical SDK.
//
// Run:
//   pnpm devstack up        # attached supervisor: sui + local Seal + publish + serve
//   pnpm devstack apply     # reconcile through a live supervisor, or one-shot

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
	// walrus, walCoin,  // uncomment for a local Walrus cluster (attachments only); see note below
} from '@mysten-incubation/devstack';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..');
const DEV_PORT = 5173;

// --- Patched build sources (the one risky bit) ------------------------------
// `localPackage()` builds from `sourcePath` with `sui move build -e testnet …
// --with-unpublished-dependencies` (the `-e testnet` is hardcoded in devstack
// 0.1.1), then `Transaction.publish`. `--with-unpublished-dependencies` is the
// `--publish-unpublished-deps` equivalent: it bundles *unpublished* transitive
// deps into the one publish tx. The catch: a dep that ships a committed
// `Published.toml` with a `[published.testnet]` entry (here, `sui_groups`) is
// resolved by the `-e testnet` build to its on-chain testnet id and *linked*
// rather than bundled — and that id doesn't exist on localnet, so the publish
// fails ("Dependent package not found on-chain"). devstack does NOT patch
// Move.toml or scrub `Published.toml`, so we pre-stage COPIES (canonical package
// untouched), mirroring the localnet test path's end-state
// (`sui client test-publish` against the live chain, where sui_groups is
// unpublished and gets bundled):
//   - `suins = { r.mvr = "@suins/core" }`  ->  a LOCAL copy with `Published.toml`/
//     `Move.lock` stripped (MVR doesn't resolve on localnet; and although this suins
//     rev ships no `Published.toml`, its committed `Move.lock` carries `[env]`
//     published-ids that the `-e testnet` build would otherwise link to instead of
//     bundling — so it gets the same local-copy + strip treatment as sui_groups).
//   - `sui_groups`  ->  a LOCAL copy with `Published.toml`/`Move.lock` stripped, so
//     the `-e testnet` build treats it as unpublished and bundles it. devstack copies
//     local deps into its build scratch; git deps would keep their published addresses.
//   - drop messaging's own `Published.toml`/`Move.lock` so it publishes fresh on localnet.
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
// suins ships no Published.toml at this rev, but its committed Move.lock carries
// `[env]` published-ids (testnet 0x40eee27b…). As a git dep those leak through and
// the `-e testnet` build LINKS to that id instead of bundling — and it isn't on
// localnet. So materialize a LOCAL copy with Published.toml/Move.lock stripped,
// same as sui_groups, so the build treats suins as unpublished and bundles it.
const SUINS_GIT = 'https://github.com/MystenLabs/suins-contracts.git';
const SUINS_REV = '2b75990bdc31472405a6bf47b40152627a1fa6c0';
const SUINS_DEP = 'suins = { local = "../suins/packages/suins" }';

// Strip committed published addresses + lockfile so the `-e testnet` build treats a
// package as UNPUBLISHED on localnet and bundles it.
function stripPublished(pkgDir: string) {
	rmSync(resolve(pkgDir, 'Published.toml'), { force: true });
	rmSync(resolve(pkgDir, 'Move.lock'), { force: true });
}

function materializeSuiGroups() {
	if (!existsSync(resolve(PATCHED_GROUPS_PKG, 'Move.toml'))) {
		rmSync(PATCHED_GROUPS, { recursive: true, force: true });
		execFileSync('git', ['clone', '--quiet', SUI_GROUPS_GIT, PATCHED_GROUPS], { stdio: 'inherit' });
		execFileSync('git', ['-C', PATCHED_GROUPS, 'checkout', '--quiet', SUI_GROUPS_REV], {
			stdio: 'inherit',
		});
	}
	stripPublished(PATCHED_GROUPS_PKG);
}

function materializeSuins() {
	if (!existsSync(resolve(PATCHED_SUINS_PKG, 'Move.toml'))) {
		rmSync(PATCHED_SUINS, { recursive: true, force: true });
		execFileSync('git', ['clone', '--quiet', SUINS_GIT, PATCHED_SUINS], { stdio: 'inherit' });
		execFileSync('git', ['-C', PATCHED_SUINS, 'checkout', '--quiet', SUINS_REV], {
			stdio: 'inherit',
		});
	}
	stripPublished(PATCHED_SUINS_PKG);
}

function materializeMessaging() {
	rmSync(PATCHED_MESSAGING, { recursive: true, force: true });
	cpSync(CANONICAL_MESSAGING, PATCHED_MESSAGING, {
		recursive: true,
		// Skip build artifacts and the pinned lockfile — sui move build regenerates them.
		filter: (src) => !/[/\\]build([/\\]|$)/.test(src) && !/[/\\]Move\.lock$/.test(src),
	});
	const tomlPath = resolve(PATCHED_MESSAGING, 'Move.toml');
	const toml = readFileSync(tomlPath, 'utf8')
		.replace('suins = { r.mvr = "@suins/core" }', SUINS_DEP)
		.replace(
			/^sui_groups = \{ git =.*$/m,
			'sui_groups = { local = "../sui_groups/move/packages/sui_groups" }',
		);
	writeFileSync(tomlPath, toml);
	stripPublished(PATCHED_MESSAGING);
}

materializeSuiGroups();
materializeSuins();
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
// One local-keygen key server: it BLS-keygens a master key, publishes the Seal Move
// package, registers an on-chain KeyServer bound to the in-stack RPC, and serves it.
// (devstack 0.1.1 can boot two local-keygen servers, but its codegen collides on the
// two duplicate Seal-package bindings — so one server, with the app using
// `sealThreshold: 1` to match.) Codegen emits `src/generated/seal/local.ts`:
//   export const sealBindings = { name, objectId, keyServerUrl, serverConfigs, mode }
// where `serverConfigs` (`[{ objectId, weight }]`) is SDK-ready for `new SealClient`.
export const keyServer = seal({ mode: 'local-keygen', signer: sealSigner, name: 'local' });

// --- Move packages ----------------------------------------------------------
// One bundled publish (sui_groups + suins + messaging in a single tx). The two
// shared singletons the SDK needs for `packageConfig.messaging` (MessagingNamespace
// + Version) and the bundled `sui_groups` package id are not surfaced by codegen,
// so the chat-app recovers all three from chain at bootstrap — see
// `src/lib/devstack-config.ts`.
export const messaging = localPackage('sui_stack_messaging', {
	sourcePath: PATCHED_MESSAGING,
	publisher,
});

// --- Dev wallet (browser) ---------------------------------------------------
// `devstackVitePlugin()` auto-injects this into the app; dapp-kit's ConnectButton
// then lists it (pre-funded accounts, no extension, no faucet step).
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
	// Wait for chain, key server, package publish, and wallet before serving.
	after: [messaging, keyServer, devWallet] as const,
});

export default defineDevstack({
	members: [localnet, keyServer, messaging, devWallet, app],
	stackName: 'chat-app-local',
	codegen: { outputDir: 'src/generated' },
});

// --- Optional: local Walrus cluster (attachments only) ----------------------
// Walrus is OPTIONAL — only message ATTACHMENTS need it; messaging and
// decryption do not. The local-cluster factory is `walrus({ local: { nodeCount, shards } })`
// (a heavy container boot). To enable: import `{ walrus, walCoin }` above, then e.g.
//   export const blobs = walrus({ local: { nodeCount: 1, shards: 4 } });
// add `blobs` to `members`, and fund WAL via `walCoin(blobs)`.

// --- Relayer ----------------------------------------------------------------
// devstack does NOT run the reference relayer, but the SDK send/fetch path goes
// through it. Run it separately (host process) pointed at the DIRECT host-published
// validator port — `docker port <sui-validator> 9000` — NOT the Traefik-routed :9000
// (the relayer's gRPC checkpoint subscription 400s through the router). `GROUPS_PACKAGE_ID`
// = the merged package id (src/generated/packages.ts), `SUI_RPC_URL` = that host-published
// port. The chat-app reads `VITE_RELAYER_URL` (default http://localhost:3000).

// --- How the app consumes the generated output ------------------------------
// `devstackVitePlugin()` (added in vite.config.ts, dev-only) ONLY aliases `@generated`
// to this `outputDir` — it does NOT inject a wallet. The app reads the generated modules
// through a `virtual:devstack-app-config` shim (so non-devstack builds never import
// `@generated`) + `src/lib/devstack-config.ts`. It maps:
//   @generated/seal/local (sealBindings.serverConfigs) -> SealClient serverConfigs (threshold 1)
//   @generated/packages (packages.sui_stack_messaging.packageId) -> packageConfig.messaging
//   @generated/sui/network (suiNetwork.{rpcUrl,graphqlUrl})      -> base gRPC client + GraphQL
//   @generated/dapp-kit/config (walletUrl,pairUrl,chain)         -> dev-wallet registration + network
// The shim also builds the dev-wallet `walletInitializers` entry (DevstackSignerAdapter wrapped in
// devWalletInitializer) — devstack runs the wallet server, but the app hands the initializer to
// createDAppKit (src/lib/dapp-kit.ts), which registers the wallet. MessagingNamespace + Version +
// the merged sui_groups id are recovered from the publish tx at bootstrap (not surfaced by codegen);
// mvr overrides `@local-pkg/sui-stack-messaging` / `@local-pkg/sui-groups` are set on the base client.
//
// Node tooling (not the browser) can read the runtime manifest via
// `@mysten-incubation/devstack/runtime` (`readStackContext`); the browser path is the generated imports.
