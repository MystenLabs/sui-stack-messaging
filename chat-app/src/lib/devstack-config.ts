// Bridges the @mysten-incubation/devstack generated config into the SDK client,
// for the fully-local stack (local Sui + local Seal key server + local Walrus).
// Everything here is inert unless launched by `devstack up`: outside a devstack
// run the `virtual:devstack-app-config` shim exports `null` and `isDevstack` is
// false, so the app keeps its normal testnet env path untouched.
//
// See `chat-app/devstack.config.ts` and the `spin-up-local-devstack` skill.

import { devstack } from 'virtual:devstack-app-config';
import type { ClientWithCoreApi } from '@mysten/sui/client';
import { SuiGrpcClient } from '@mysten/sui/grpc';

const MESSAGING_PACKAGE = 'sui_stack_messaging';
// MVR named addresses the SDK's generated bindings resolve through. Must be mapped
// to the locally-published ids on the base client (mirrors the test helper
// `test/helpers/create-sui-stack-messaging-client.ts`). devstack normalizes its own
// placeholders under `@local/`, so it cannot carry these names — they are mapped by
// hand here. `sui_groups` is bundled into the same publish, so both names resolve
// to the one merged package id.
const MVR_MESSAGING = '@local-pkg/sui-stack-messaging';
const MVR_GROUPS = '@local-pkg/sui-groups';

export const isDevstack = devstack != null;

interface DevstackNetworkInfo {
  /** dapp-kit network key (the deployment envelope's network name, `localnet`). */
  key: string;
  rpcUrl: string;
  graphqlUrl: string | null;
}

/** Sync network info from the generated config (available at module load). */
export const devstackNetwork: DevstackNetworkInfo | null = devstack
  ? {
      key: devstack.networkName,
      rpcUrl: devstack.network.rpc,
      // devstack exposes the GraphQL host without a path; the endpoint is `/graphql`.
      graphqlUrl: devstack.network.graphql ? `${devstack.network.graphql}/graphql` : null,
    }
  : null;

interface MessagingPackageConfig {
  originalPackageId: string;
  latestPackageId: string;
  namespaceId: string;
  versionId: string;
}

interface PermissionedGroupsPackageConfig {
  originalPackageId: string;
  latestPackageId: string;
}

export interface DevstackClientConfig {
  baseClient: ClientWithCoreApi;
  sealServerConfigs: { objectId: string; weight: number }[];
  packageConfig: {
    messaging: MessagingPackageConfig;
    permissionedGroups: PermissionedGroupsPackageConfig;
  };
  /** Local Walrus client-service URLs for the attachments adapter. */
  walrus: {
    publisherUrl: string | null;
    aggregatorUrl: string | null;
  };
}

let cached: DevstackClientConfig | null = null;

/**
 * Builds the full SDK config for the local devstack from the generated config:
 * the locally-published messaging id + the captured MessagingNamespace/Version
 * singletons (surfaced by the `capture` option in devstack.config.ts), the local
 * Seal server configs, the local Walrus publisher/aggregator URLs, and a gRPC
 * base client with the MVR overrides the SDK bindings need. The bundled
 * `sui_groups` merges into the messaging publish on localnet, so its id IS the
 * messaging package id. Throws if called outside a devstack run.
 */
export function getDevstackClientConfig(): DevstackClientConfig {
  if (cached) return cached;
  if (!devstack || !devstackNetwork) {
    throw new Error('getDevstackClientConfig called outside a devstack run');
  }

  const pkg = devstack.network.packages[MESSAGING_PACKAGE];
  if (!pkg?.id) {
    throw new Error(`devstack generated config missing packages.${MESSAGING_PACKAGE}.id`);
  }
  const messagingId = pkg.id;
  const namespaceId = pkg.objects?.namespaceId;
  const versionId = pkg.objects?.versionId;
  if (!namespaceId || !versionId) {
    throw new Error(
      `devstack generated config missing captured objects for ${MESSAGING_PACKAGE} ` +
        `(namespaceId=${namespaceId ?? 'missing'} versionId=${versionId ?? 'missing'}) — ` +
        `check the localPackage capture option in devstack.config.ts`,
    );
  }

  const sealServerConfigs = devstack.seal.flatMap((s) =>
    s.serverConfigs.map((c) => ({ objectId: c.objectId, weight: c.weight ?? 1 })),
  );
  if (sealServerConfigs.length === 0) {
    throw new Error('devstack generated seal config has no server configs');
  }

  const baseClient = new SuiGrpcClient({
    baseUrl: devstackNetwork.rpcUrl,
    network: devstackNetwork.key as ConstructorParameters<typeof SuiGrpcClient>[0]['network'],
    mvr: {
      overrides: {
        packages: {
          [MVR_MESSAGING]: messagingId,
          [MVR_GROUPS]: messagingId,
        },
      },
    },
  }) as unknown as ClientWithCoreApi;

  cached = {
    baseClient,
    sealServerConfigs,
    packageConfig: {
      messaging: {
        originalPackageId: messagingId,
        latestPackageId: messagingId,
        namespaceId,
        versionId,
      },
      permissionedGroups: {
        originalPackageId: messagingId,
        latestPackageId: messagingId,
      },
    },
    walrus: {
      publisherUrl: devstack.walrus.publisherUrl,
      aggregatorUrl: devstack.walrus.aggregatorUrl,
    },
  };
  return cached;
}
