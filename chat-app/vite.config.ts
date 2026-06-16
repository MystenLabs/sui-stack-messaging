import { defineConfig, loadEnv, type Plugin, type PluginOption } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// True only when launched by `devstack up` — devstack injects these into the
// host-service child process. Keeps the incubation dep + generated config off the
// normal `pnpm dev` / `pnpm build` path entirely.
const DEVSTACK_ACTIVE = !!process.env.DEVSTACK_RUNTIME_ROOT || !!process.env.DEVSTACK_STACK;

// Resolves `virtual:devstack-app-config` to a single `devstack` object composed from
// the devstack-generated modules under a devstack run, and to `null` otherwise — so
// committed app code can import it unconditionally without ever statically referencing
// `@generated` (which only exists when `devstackVitePlugin()` is active).
const SHIM_ACTIVE_SOURCE = [
  `import { devWalletInitializer } from '@mysten-incubation/dev-wallet';`,
  `import { DevstackSignerAdapter, parseDevstackToken } from '@mysten-incubation/dev-wallet/adapters';`,
  `import { sealBindings as s1 } from '@generated/seal/local';`,
  `import { packages } from '@generated/packages';`,
  `import { suiNetwork } from '@generated/sui/network';`,
  `import { dappKitConfig } from '@generated/dapp-kit/config';`,
  // devstack runs the dev-wallet server (funded accounts; keys stay server-side, signing
  // goes through /api/v1/devstack/*). The initializer goes into dApp Kit's
  // `walletInitializers` (see src/lib/dapp-kit.ts), which registers the wallet (so
  // ConnectButton lists it), initializes the adapter, and mounts the floating approval UI.
  `const walletInitializers = [`,
  `  devWalletInitializer({`,
  `    adapters: [new DevstackSignerAdapter({ serverOrigin: dappKitConfig.walletUrl, token: parseDevstackToken(dappKitConfig.pairUrl) })],`,
  // Accounts come from the devstack wallet server; never create a local one.
  `    createInitialAccount: false,`,
  `    mountUI: true,`,
  // The initializer inherits dApp Kit's networks list in declaration order (testnet
  // first); pin the panel to localnet so its balances/faucet target the in-stack node.
  `    onWalletCreated: (wallet) => wallet.setActiveNetwork('localnet'),`,
  `  }),`,
  `];`,
  `export const devstack = { seal: [s1], packages, network: suiNetwork, dappKit: dappKitConfig, walletInitializers };`,
].join('\n');

function devstackAppConfigShim(active: boolean): Plugin {
  const VIRTUAL_ID = 'virtual:devstack-app-config';
  const RESOLVED_ID = '\0' + VIRTUAL_ID;
  return {
    name: 'devstack-app-config-shim',
    enforce: 'pre',
    resolveId(id) {
      if (id === VIRTUAL_ID) return RESOLVED_ID;
    },
    load(id) {
      if (id !== RESOLVED_ID) return;
      return active ? SHIM_ACTIVE_SOURCE : `export const devstack = null;`;
    },
  };
}

export default defineConfig(async ({ mode }) => {
  const env = loadEnv(mode, '.', '');

  const plugins: PluginOption[] = [tailwindcss(), react()];

  if (DEVSTACK_ACTIVE) {
    // Aliases `@generated` / `@devstack-dev`. It does NOT register the dev wallet — that is the
    // shim's `walletInitializers` entry (SHIM_ACTIVE_SOURCE), passed to createDAppKit.
    const { devstackVitePlugin } = await import('@mysten-incubation/devstack/vite');
    plugins.push(devstackVitePlugin());
  }
  plugins.push(devstackAppConfigShim(DEVSTACK_ACTIVE));

  return {
    plugins,
    server: {
      proxy: {
        '/api/relayer': {
          target: env.VITE_RELAYER_BACKEND_URL || 'http://localhost:3000',
          changeOrigin: true,
          rewrite: (path: string) => path.replace(/^\/api\/relayer/, ''),
        },
        '/api/graphql': {
          target: 'https://graphql.testnet.sui.io',
          changeOrigin: true,
          rewrite: (path: string) => path.replace(/^\/api\/graphql/, '/graphql'),
        },
      },
    },
  };
});
