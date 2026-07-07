/// <reference types="vite/client" />

// devstack generated-config shape (the subset the chat-app reads), composed by the
// `virtual:devstack-app-config` shim in vite.config.ts from the `@generated/*` modules
// devstack codegen writes (config/seal/walrus, resolved for the local network via
// `forNetwork`). `devstack` is `null` outside a `devstack up` run.
// Consumed by src/lib/devstack-config.ts.
declare module 'virtual:devstack-app-config' {
  /** One network's resolved deployment entry (devstack `NetworkDeployment`). */
  export interface DevstackNetworkEntry {
    rpc: string;
    chainId?: string;
    faucet?: string | null;
    graphql?: string | null;
    local?: boolean;
    packages: Record<string, { id: string; objects?: Record<string, string> }>;
    mvrOverrides: {
      packages: Record<string, string>;
      types: Record<string, string>;
    };
    values?: Record<string, Record<string, unknown>>;
  }
  export interface DevstackSealBindings {
    name: string;
    objectId: string;
    keyServerUrl: string;
    mode: string;
    verifyKeyServers: boolean;
    serverConfigs: readonly {
      readonly objectId: string;
      readonly weight: number;
      readonly aggregatorUrl?: string;
    }[];
  }
  export interface DevstackWalrusBindings {
    mode: string;
    network: string;
    publisherUrl: string | null;
    aggregatorUrl: string | null;
    uploadRelayUrl: string | null;
    proxyUrl: string | null;
    walCoinType: string | null;
    packageConfig: {
      systemObjectId: string;
      stakingPoolId: string;
      exchangeIds?: readonly string[];
    };
  }
  export interface DevstackGenerated {
    /** The local stack's network name (the deployment envelope default, `localnet`). */
    networkName: string;
    network: DevstackNetworkEntry;
    seal: DevstackSealBindings[];
    walrus: DevstackWalrusBindings;
  }
  export const devstack: DevstackGenerated | null;
}
