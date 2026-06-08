import { createNetworkConfig } from '@mysten/dapp-kit';
import { getJsonRpcFullnodeUrl } from '@mysten/sui/jsonRpc';
import { devstackNetwork, isDevstack } from './devstack-config';

const rpcUrl = import.meta.env.VITE_SUI_RPC_URL;

const testnet = {
  url: rpcUrl || getJsonRpcFullnodeUrl('testnet'),
  network: 'testnet' as const,
};

// Under `devstack up`, add a local network keyed by the devstack chain id and make
// it the default — this is the chain the injected dev wallet reports, so dapp-kit
// connects on the same chain. Outside devstack, testnet-only (unchanged).
const networks =
  isDevstack && devstackNetwork
    ? { [devstackNetwork.key]: { url: devstackNetwork.rpcUrl, network: 'localnet' as const }, testnet }
    : { testnet };

export const defaultNetwork = isDevstack && devstackNetwork ? devstackNetwork.key : 'testnet';

const { networkConfig, useNetworkVariable } = createNetworkConfig(networks);

export { networkConfig, useNetworkVariable };
