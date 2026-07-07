import 'dotenv/config';

export type Network = 'testnet' | 'mainnet' | 'localnet';

export interface Config {
  network: Network;
  grpcUrl: string;
  walrusPackageId: string;
  /** When set, blob inspection goes through this Walrus aggregator's HTTP API
   *  instead of the @mysten/walrus SDK. Required on localnet: the SDK reads
   *  quilt indexes from the storage nodes directly, and a local cluster's
   *  committee hostnames only resolve inside its Docker network. */
  aggregatorUrl?: string;
  publisherSuiAddress?: string;
  port: number;
}

const GRPC_URLS: Record<'testnet' | 'mainnet', string> = {
  testnet: 'https://fullnode.testnet.sui.io:443',
  mainnet: 'https://fullnode.mainnet.sui.io:443',
};

// Load and validate environment variables into a typed config object.
// `walrusPackageId` stays optional here: on testnet/mainnet it is auto-derived
// from the network's system object at startup (see index.ts); on localnet it
// must be provided (WALRUS_PACKAGE_ID) along with the local gRPC and
// aggregator endpoints.
export function loadConfig(): Omit<Config, 'walrusPackageId'> & { walrusPackageId?: string } {
  const network = process.env.NETWORK as Network;
  if (!network || !['testnet', 'mainnet', 'localnet'].includes(network)) {
    throw new Error('NETWORK must be "testnet", "mainnet" or "localnet"');
  }

  const grpcUrl =
    process.env.SUI_GRPC_URL || (network === 'localnet' ? undefined : GRPC_URLS[network]);
  const walrusPackageId = process.env.WALRUS_PACKAGE_ID || undefined;
  const aggregatorUrl = process.env.WALRUS_AGGREGATOR_URL?.replace(/\/+$/, '') || undefined;

  if (network === 'localnet') {
    const missing = [
      !grpcUrl && 'SUI_GRPC_URL',
      !walrusPackageId && 'WALRUS_PACKAGE_ID',
      !aggregatorUrl && 'WALRUS_AGGREGATOR_URL',
    ].filter(Boolean);
    if (missing.length > 0) {
      throw new Error(
        `NETWORK=localnet requires ${missing.join(', ')} — ` +
          'run via chat-app/scripts/local-indexer.sh to extract them from a devstack stack',
      );
    }
  }

  return {
    network,
    grpcUrl: grpcUrl!,
    walrusPackageId,
    aggregatorUrl,
    publisherSuiAddress: process.env.WALRUS_PUBLISHER_SUI_ADDRESS || undefined,
    port: parseInt(process.env.PORT || '3001', 10),
  };
}
