/// <reference types="vite/client" />

// devstack generated-config shape (the subset the chat-app reads), composed by the
// `virtual:devstack-app-config` shim in vite.config.ts from the `@generated/*` modules
// devstack codegen writes. `devstack` is `null` outside a `devstack up` run.
// Consumed by src/lib/devstack-config.ts.
declare module 'virtual:devstack-app-config' {
  export interface DevstackSealBindings {
    name: string;
    objectId: string;
    keyServerUrl: string;
    mode: string;
    serverConfigs: { objectId: string; weight?: number; aggregatorUrl?: string }[];
  }
  export interface DevstackPackage {
    name: string;
    packageId: string;
    mvrPlaceholder: string;
    sourcePath: string;
    excluded: boolean;
  }
  export interface DevstackSuiNetwork {
    chain: string;
    mode: string;
    rpcUrl: string;
    graphqlUrl: string | null;
    faucetUrl: string | null;
    forkUpstream: string | null;
  }
  export interface DevstackDappKitConfig {
    chain: string;
    pairUrl: string;
    walletUrl: string;
  }
  export interface DevstackGenerated {
    seal: DevstackSealBindings[];
    packages: Record<string, DevstackPackage>;
    network: DevstackSuiNetwork;
    dappKit: DevstackDappKitConfig;
    /** Dev-wallet initializer for `createDAppKit({ walletInitializers })`. */
    walletInitializers: import('@mysten/dapp-kit-core').WalletInitializer[];
  }
  export const devstack: DevstackGenerated | null;
}
