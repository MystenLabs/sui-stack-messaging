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
// `@generated`. The generated modules are id-free stubs that resolve through the
// deployment envelope `devstackVitePlugin()` injects, so evaluating them OUTSIDE a
// devstack run throws — the shim gate keeps them off the normal env path entirely.
// The dev wallet needs no wiring here: the plugin injects and registers it on the
// page in dev (wallet-standard auto-discovery).
const SHIM_ACTIVE_SOURCE = [
  `import { config } from '@generated/config.js';`,
  `import { seal } from '@generated/seal.js';`,
  `import { walrus } from '@generated/walrus.js';`,
  // The local stack's single network ('localnet'); forNetwork resolves that
  // network's deployment entry (rpc/graphql, packages incl. captured object ids,
  // mvrOverrides) from the injected envelope.
  `const networkName = config.defaultNetwork;`,
  `export const devstack = {`,
  `  networkName,`,
  `  network: config.forNetwork(networkName),`,
  `  seal: Object.values(seal.forNetwork(networkName)),`,
  `  walrus: walrus.forNetwork(networkName),`,
  `};`,
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
    // Aliases `@generated`, injects the deployment envelope (`__DEVSTACK_DEPLOYMENT__`),
    // and injects + registers the dev wallet on the page (dev-only).
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
