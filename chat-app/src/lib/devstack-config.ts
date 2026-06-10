// Bridges the @mysten-incubation/devstack generated config into the SDK client,
// for the fully-local stack (local Sui + local Seal key servers). Everything here
// is inert unless launched by `devstack up`: outside a devstack run the
// `virtual:devstack-app-config` shim exports `null` and `isDevstack` is false, so
// the app keeps its normal testnet env path untouched.
//
// See `chat-app/devstack.config.ts` and the `spin-up-local-devstack` skill.

import { devstack } from 'virtual:devstack-app-config';
import type { ClientWithCoreApi } from '@mysten/sui/client';
import { SuiGrpcClient } from '@mysten/sui/grpc';
import { SuiGraphQLClient } from '@mysten/sui/graphql';

const MESSAGING_PACKAGE = 'sui_stack_messaging';
// MVR named addresses the SDK's generated bindings resolve through. Must be mapped
// to the locally-published ids on the base client (mirrors the test helper
// `test/helpers/create-sui-stack-messaging-client.ts`).
const MVR_MESSAGING = '@local-pkg/sui-stack-messaging';
const MVR_GROUPS = '@local-pkg/sui-groups';

export const isDevstack = devstack != null;

interface DevstackNetworkInfo {
  /** dapp-kit network key, derived from the dev-wallet chain id (e.g. `sui:local` -> `local`). */
  key: string;
  rpcUrl: string;
  graphqlUrl: string | null;
}

/** Sync network info from the generated config (available at module load). */
export const devstackNetwork: DevstackNetworkInfo | null = devstack
  ? {
      // Use the standard `localnet` dapp-kit key: the dev-wallet client reports
      // `sui:localnet` chains, so dapp-kit must be on `localnet` to match it (devstack's
      // own chain id is `sui:local`, which the wallet client does not advertise).
      key: 'localnet',
      rpcUrl: devstack.network.rpcUrl,
      // devstack exposes the GraphQL host without a path; the endpoint is `/graphql`.
      graphqlUrl: devstack.network.graphqlUrl ? `${devstack.network.graphqlUrl}/graphql` : null,
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
}

/**
 * Builds the full SDK config for the local devstack: resolves the locally-published
 * messaging id + the local Seal server configs from the generated config, recovers
 * the shared singletons (MessagingNamespace, Version) and the bundled `sui_groups`
 * id from chain, and returns a gRPC base client with the MVR overrides the SDK
 * bindings need. Throws if called outside a devstack run.
 */
export async function loadDevstackClientConfig(): Promise<DevstackClientConfig> {
  if (!devstack || !devstackNetwork) {
    throw new Error('loadDevstackClientConfig called outside a devstack run');
  }

  const pkg = devstack.packages[MESSAGING_PACKAGE];
  if (!pkg?.packageId) {
    throw new Error(`devstack generated config missing packages.${MESSAGING_PACKAGE}.packageId`);
  }
  const messagingId = pkg.packageId;

  // Both local key servers' configs -> default Seal threshold of 2 holds.
  const sealServerConfigs = devstack.seal.flatMap((s) =>
    s.serverConfigs.map((c) => ({ objectId: c.objectId, weight: c.weight ?? 1 })),
  );
  if (sealServerConfigs.length === 0) {
    throw new Error('devstack generated seal config has no server configs');
  }

  const { namespaceId, versionId, groupsId } = await recoverPublishedObjects(
    messagingId,
    devstackNetwork.graphqlUrl,
  );

  const baseClient = new SuiGrpcClient({
    baseUrl: devstackNetwork.rpcUrl,
    network: devstackNetwork.key as ConstructorParameters<typeof SuiGrpcClient>[0]['network'],
    mvr: {
      overrides: {
        packages: {
          [MVR_MESSAGING]: messagingId,
          [MVR_GROUPS]: groupsId,
        },
      },
    },
  }) as unknown as ClientWithCoreApi;

  return {
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
        originalPackageId: groupsId,
        latestPackageId: groupsId,
      },
    },
  };
}

interface RecoveredObjects {
  namespaceId: string;
  versionId: string;
  groupsId: string;
}

/**
 * Recovers the three things devstack codegen doesn't surface for a bundled publish:
 * the `MessagingNamespace` + `Version` shared singletons, and the locally-published
 * `sui_groups` package id (bundled into the messaging publish tx via
 * `--with-unpublished-dependencies`). Reads the messaging package's publish tx via
 * GraphQL — namespace/version are created MoveObjects matched by type; sui_groups is
 * the created MovePackage exposing the `permissioned_group` module. Retries briefly to
 * tolerate indexer lag right after publish.
 */
async function recoverPublishedObjects(
  messagingId: string,
  graphqlUrl: string | null,
): Promise<RecoveredObjects> {
  if (!graphqlUrl) {
    throw new Error('devstack local GraphQL URL missing — cannot recover published objects');
  }
  const gql = new SuiGraphQLClient({ url: graphqlUrl, network: 'localnet' });

  let lastErr: unknown;
  for (let attempt = 0; attempt < 10; attempt++) {
    try {
      const digest = await fetchPublishDigest(gql, messagingId);
      const recovered = await fetchRecovered(gql, digest);
      if (recovered.namespaceId && recovered.versionId && recovered.groupsId) {
        return recovered as RecoveredObjects;
      }
      throw new Error(
        `publish tx not fully indexed yet (namespace=${!!recovered.namespaceId} ` +
          `version=${!!recovered.versionId} groups=${!!recovered.groupsId})`,
      );
    } catch (err) {
      lastErr = err;
      await delay(1000);
    }
  }
  throw new Error(
    `Failed to recover published objects from messaging ${messagingId}: ${String(lastErr)}`,
  );
}

interface DigestResponse {
  object?: { previousTransaction?: { digest: string } | null } | null;
}

async function fetchPublishDigest(gql: SuiGraphQLClient, packageId: string): Promise<string> {
  const { data, errors } = await gql.query({
    query: `query Publish($address: SuiAddress!) {
      object(address: $address) { previousTransaction { digest } }
    }`,
    variables: { address: packageId },
  });
  if (errors?.length) throw new Error(errors.map((e) => e.message).join('; '));
  const digest = (data as DigestResponse | null)?.object?.previousTransaction?.digest;
  if (!digest) throw new Error('messaging package publish tx not available yet');
  return digest;
}

interface ChangesResponse {
  transaction?: {
    effects?: {
      objectChanges?: {
        nodes: {
          address: string;
          outputState?: {
            asMoveObject?: { contents?: { type?: { repr?: string } | null } | null } | null;
            asMovePackage?: { module?: { name: string } | null } | null;
          } | null;
        }[];
      } | null;
    } | null;
  } | null;
}

async function fetchRecovered(
  gql: SuiGraphQLClient,
  digest: string,
): Promise<Partial<RecoveredObjects>> {
  const { data, errors } = await gql.query({
    query: `query Changes($digest: String!) {
      transaction(digest: $digest) {
        effects {
          objectChanges(first: 60) {
            nodes {
              address
              outputState {
                asMoveObject { contents { type { repr } } }
                asMovePackage { module(name: "permissioned_group") { name } }
              }
            }
          }
        }
      }
    }`,
    variables: { digest },
  });
  if (errors?.length) throw new Error(errors.map((e) => e.message).join('; '));
  const nodes = (data as ChangesResponse | null)?.transaction?.effects?.objectChanges?.nodes;
  if (!nodes) throw new Error('publish tx object changes not available yet');

  const out: Partial<RecoveredObjects> = {};
  for (const node of nodes) {
    const repr = node.outputState?.asMoveObject?.contents?.type?.repr;
    if (repr?.includes('MessagingNamespace')) out.namespaceId = node.address;
    else if (repr?.includes('::version::Version')) out.versionId = node.address;
    else if (node.outputState?.asMovePackage?.module?.name) out.groupsId = node.address;
  }
  return out;
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
