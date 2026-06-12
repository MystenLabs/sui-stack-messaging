import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import {
  useCurrentAccount,
  useCurrentClient,
  useDAppKit,
} from '@mysten/dapp-kit-react';
import { createSuiStackMessagingClient, WalrusHttpStorageAdapter } from '@mysten/sui-stack-messaging';
import { SuiGraphQLClient } from '@mysten/sui/graphql';
import { DappKitSigner } from '../lib/dapp-kit-signer';
import {
  devstackNetwork,
  isDevstack,
  loadDevstackClientConfig,
  type DevstackClientConfig,
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
const graphqlClient = new SuiGraphQLClient({ url: GRAPHQL_URL, network: 'testnet' });

export function MessagingClientProvider({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  const account = useCurrentAccount();
  const suiClient = useCurrentClient();
  const dAppKit = useDAppKit();

  // Serialize wallet sign requests. The Seal session-key flow and tx signing can each
  // trigger a personal-message sign, and they can overlap (more so under React StrictMode).
  // dApp Kit does not queue wallet requests, and the devstack dev-wallet — like some real
  // wallets — rejects a second concurrent sign with "a signing request is already pending";
  // queueing keeps at most one in flight.
  const signChain = useRef<Promise<unknown>>(Promise.resolve());
  const queuedSign = useCallback((args: { message: Uint8Array }): Promise<{ signature: string }> => {
    const run = signChain.current.then(() => dAppKit.signPersonalMessage(args));
    signChain.current = run.catch(() => undefined);
    return run;
  }, [dAppKit]);

  // Local devstack: resolve the generated config (local RPC + seal + package ids)
  // and recover the bundled sui_groups id once, independent of the wallet.
  const [devstackCfg, setDevstackCfg] = useState<DevstackClientConfig | null>(null);
  useEffect(() => {
    if (!isDevstack) return;
    let cancelled = false;
    loadDevstackClientConfig()
      .then((cfg) => {
        if (!cancelled) setDevstackCfg(cfg);
      })
      .catch((err) => console.error('[devstack] failed to load local config', err));
    return () => {
      cancelled = true;
    };
  }, []);

  const { client, signer } = useMemo(() => {
    if (!account) return { client: null, signer: null };
    // In devstack mode, wait for the local config before building the client.
    if (isDevstack && !devstackCfg) return { client: null, signer: null };

    const signer = new DappKitSigner({
      address: account.address,
      publicKeyBytes: account.publicKey
        ? new Uint8Array(account.publicKey)
        : undefined,
      signPersonalMessage: (args) => queuedSign({ message: args.message }),
    });

    // devstack mode sources the base client (local RPC + MVR overrides), seal
    // server configs and package ids from the generated config; otherwise env.
    const baseClient = devstackCfg?.baseClient ?? suiClient;
    const sealServerConfigs = devstackCfg?.sealServerConfigs ?? parseSealServerConfigs();
    const packageConfig = devstackCfg?.packageConfig ?? parsePackageConfig();

    // Build optional attachments config when Walrus URLs are provided
    const attachments =
      WALRUS_PUBLISHER_URL && WALRUS_AGGREGATOR_URL
        ? {
            storageAdapter: new WalrusHttpStorageAdapter({
              publisherUrl: WALRUS_PUBLISHER_URL,
              aggregatorUrl: WALRUS_AGGREGATOR_URL,
              epochs: WALRUS_EPOCHS,
              fetch: (...args) => fetch(...args),
            }),
            maxFileSizeBytes: 5 * 1024 * 1024, // 5 MB per file
            maxAttachments: 10,
          }
        : undefined;

    const client = createSuiStackMessagingClient(baseClient, {
      seal: {
        serverConfigs: sealServerConfigs,
      },
      encryption: {
        sessionKey: {
          address: account.address,
          onSign: async (message: Uint8Array) => {
            const { signature } = await queuedSign({ message });
            return signature;
          },
        },
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

    return { client, signer };
  }, [account, suiClient, devstackCfg, queuedSign]);

  const value = useMemo(
    () => ({ client, signer, graphqlClient }),
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
