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
  `import { DevWallet } from '@mysten-incubation/dev-wallet';`,
  `import { DevstackSignerAdapter, parseDevstackToken } from '@mysten-incubation/dev-wallet/adapters';`,
  `import { mountDevWallet } from '@mysten-incubation/dev-wallet/ui';`,
  `import { sealBindings as s1 } from '@generated/seal/local';`,
  `import { packages } from '@generated/packages';`,
  `import { suiNetwork } from '@generated/sui/network';`,
  `import { dappKitConfig } from '@generated/dapp-kit/config';`,
  // devstack runs the dev-wallet server (funded accounts; keys stay server-side, signing
  // goes through /api/v1/devstack/*). Build the server-delegating adapter, load its accounts,
  // register the wallet (so the existing <WalletProvider>/ConnectButton lists it), and mount
  // the floating panel (so connect/sign approvals have a UI). Side effect on shim load.
  `const __adapter = new DevstackSignerAdapter({ serverOrigin: dappKitConfig.walletUrl, token: parseDevstackToken(dappKitConfig.pairUrl) });`,
  `try { await __adapter.initialize(); } catch (e) { console.error('[devstack] dev-wallet adapter init failed', e); }`,
  `const __wallet = new DevWallet({ adapters: [__adapter], networks: { localnet: suiNetwork.rpcUrl } });`,
  `__wallet.register();`,
  `mountDevWallet(__wallet);`,
  `export const devstack = { seal: [s1], packages, network: suiNetwork, dappKit: dappKitConfig };`,
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
    // Aliases `@generated` / `@devstack-dev` and auto-injects the dev wallet.
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
