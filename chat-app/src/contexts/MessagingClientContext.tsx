import { createContext, useContext, useMemo, type ReactNode } from 'react';
import {
  useCurrentAccount,
  useCurrentClient,
  useDAppKit,
} from '@mysten/dapp-kit-react';
import { createSuiStackMessagingClient, WalrusHttpStorageAdapter } from '@mysten/sui-stack-messaging';
import { SuiGraphQLClient } from '@mysten/sui/graphql';
import { QueuedCurrentAccountSigner } from '../lib/queued-signer';
import {
  devstackNetwork,
  getDevstackClientConfig,
  isDevstack,
} from '../lib/devstack-config';

import type { Signer } from '@mysten/sui/cryptography';

// Infer the client type from the factory return
type MessagingClient = ReturnType<typeof createSuiStackMessagingClient>;

interface MessagingClientContextValue {
  client: MessagingClient | null;
  signer: Signer | null;
  graphqlClient: SuiGraphQLClient;
}

const MessagingClientContext = createContext<MessagingClientContextValue | null>(
  null,
);

// --- Environment config ---
const RELAYER_URL =
  import.meta.env.VITE_RELAYER_URL || 'http://localhost:3000';
const GRAPHQL_URL =
  (isDevstack && devstackNetwork?.graphqlUrl) ||
  import.meta.env.VITE_SUI_GRAPHQL_URL ||
  '/api/graphql';

// Walrus storage (for file attachments)
const WALRUS_PUBLISHER_URL =
  import.meta.env.VITE_WALRUS_PUBLISHER_URL || '';
const WALRUS_AGGREGATOR_URL =
  import.meta.env.VITE_WALRUS_AGGREGATOR_URL || '';
const WALRUS_EPOCHS = Number(import.meta.env.VITE_WALRUS_EPOCHS) || 1;

// Package config overrides (optional — auto-detected from network if not set).
// For localnet/devnet, also provide permissioned-groups IDs, otherwise the SDK
// auto-detects the groups package from the network (testnet/mainnet only).
function parsePackageConfig() {
  const originalPackageId = import.meta.env.VITE_MESSAGING_ORIGINAL_PACKAGE_ID;
  if (!originalPackageId) return undefined;

  const groupsOriginal = import.meta.env.VITE_PERMISSIONED_GROUPS_ORIGINAL_PACKAGE_ID;
  const permissionedGroups = groupsOriginal
    ? {
        originalPackageId: groupsOriginal,
        latestPackageId:
          import.meta.env.VITE_PERMISSIONED_GROUPS_LATEST_PACKAGE_ID || groupsOriginal,
      }
    : undefined;

  return {
    messaging: {
      originalPackageId,
      latestPackageId: import.meta.env.VITE_MESSAGING_LATEST_PACKAGE_ID || originalPackageId,
      namespaceId: import.meta.env.VITE_MESSAGING_NAMESPACE_ID || '',
      versionId: import.meta.env.VITE_MESSAGING_VERSION_ID || '',
    },
    ...(permissionedGroups ? { permissionedGroups } : {}),
  };
}

// Seal key server object IDs (comma-separated in env)
function parseSealServerConfigs(): { objectId: string; weight: number }[] {
  const ids = import.meta.env.VITE_SEAL_KEY_SERVER_OBJECT_IDS;
  if (!ids) return [];
  return ids.split(',').map((id: string) => ({
    objectId: id.trim(),
    weight: 1,
  }));
}

// Singleton GraphQL client (does not depend on wallet)
const graphqlClient = new SuiGraphQLClient({
  url: GRAPHQL_URL,
  network: isDevstack ? 'localnet' : 'testnet',
});

export function MessagingClientProvider({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  const account = useCurrentAccount();
  const suiClient = useCurrentClient();
  const dAppKit = useDAppKit();

  // Signer over the connected account. The queued subclass serializes
  // personal-message signs — the Seal session-key ceremony and relayer request
  // signing can overlap (more so under React StrictMode), and the devstack
  // dev-wallet rejects a second concurrent sign.
  const signer = useMemo(() => new QueuedCurrentAccountSigner(dAppKit), [dAppKit]);

  // Local devstack: the generated config resolves synchronously (local RPC + seal
  // + package ids incl. the captured namespace/version singletons + Walrus URLs).
  const devstackCfg = useMemo(() => (isDevstack ? getDevstackClientConfig() : null), []);

  const client = useMemo(() => {
    if (!account) return null;

    // devstack mode sources the base client (local RPC + MVR overrides), seal
    // server configs and package ids from the generated config; otherwise env.
    const baseClient = devstackCfg?.baseClient ?? suiClient;
    const sealServerConfigs = devstackCfg?.sealServerConfigs ?? parseSealServerConfigs();
    const packageConfig = devstackCfg?.packageConfig ?? parsePackageConfig();

    // Build optional attachments config when Walrus URLs are available — from the
    // local devstack Walrus publisher/aggregator, or from VITE_WALRUS_* env.
    // All-or-nothing per source: under devstack never fall back per-URL to env,
    // or a local publisher could get paired with the testnet aggregator.
    const walrusPublisherUrl = devstackCfg
      ? devstackCfg.walrus.publisherUrl
      : WALRUS_PUBLISHER_URL;
    const walrusAggregatorUrl = devstackCfg
      ? devstackCfg.walrus.aggregatorUrl
      : WALRUS_AGGREGATOR_URL;
    const attachments =
      walrusPublisherUrl && walrusAggregatorUrl
        ? {
            storageAdapter: new WalrusHttpStorageAdapter({
              publisherUrl: walrusPublisherUrl,
              aggregatorUrl: walrusAggregatorUrl,
              epochs: WALRUS_EPOCHS,
              fetch: (...args) => fetch(...args),
            }),
            maxFileSizeBytes: 5 * 1024 * 1024, // 5 MB per file
            maxAttachments: 10,
          }
        : undefined;

    return createSuiStackMessagingClient(baseClient, {
      seal: {
        serverConfigs: sealServerConfigs,
      },
      encryption: {
        // Tier 1 (signer-based): the SDK creates and certifies session keys via
        // signer.signPersonalMessage — serialized by QueuedCurrentAccountSigner.
        sessionKey: { signer },
        // Local devstack runs a single Seal key server; match the threshold to it
        // (the default of 2 assumes the testnet two-server topology).
        sealThreshold: devstackCfg ? devstackCfg.sealServerConfigs.length : undefined,
      },
      packageConfig,
      relayer: {
        relayerUrl: RELAYER_URL,
        fetch: (...args: Parameters<typeof fetch>) => fetch(...args),
      },
      attachments,
    });
  }, [account, suiClient, devstackCfg, signer]);

  const value = useMemo(
    () => ({ client, signer: client ? signer : null, graphqlClient }),
    [client, signer],
  );

  return (
    <MessagingClientContext.Provider value={value}>
      {children}
    </MessagingClientContext.Provider>
  );
}

/**
 * Access the SDK client. Returns null when wallet is disconnected.
 * Use `useRequiredMessagingClient()` when you know the wallet must be connected.
 */
export function useMessagingClient(): MessagingClient | null {
  const ctx = useContext(MessagingClientContext);
  if (!ctx) {
    throw new Error(
      'useMessagingClient must be used within <MessagingClientProvider>',
    );
  }
  return ctx.client;
}

/** Access the SDK client, throwing if wallet is disconnected. */
export function useRequiredMessagingClient(): { client: MessagingClient; signer: Signer } {
  const ctx = useContext(MessagingClientContext);
  if (!ctx) {
    throw new Error(
      'useRequiredMessagingClient must be used within <MessagingClientProvider>',
    );
  }
  if (!ctx.client || !ctx.signer) {
    throw new Error('Wallet must be connected to use messaging client');
  }
  return { client: ctx.client, signer: ctx.signer };
}

/** Access the Sui GraphQL client for group discovery queries. */
export function useGraphQLClient(): SuiGraphQLClient {
  const ctx = useContext(MessagingClientContext);
  if (!ctx) {
    throw new Error(
      'useGraphQLClient must be used within <MessagingClientProvider>',
    );
  }
  return ctx.graphqlClient;
}
