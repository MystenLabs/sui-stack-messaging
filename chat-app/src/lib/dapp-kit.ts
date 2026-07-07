import { createDAppKit } from '@mysten/dapp-kit-react';
import { SuiGrpcClient } from '@mysten/sui/grpc';
import type { Transaction } from '@mysten/sui/transactions';
import { devstackNetwork, isDevstack } from './devstack-config';

// gRPC-Web endpoint (the public fullnodes serve gRPC and JSON-RPC on the same host).
const TESTNET_GRPC_URL =
  import.meta.env.VITE_SUI_RPC_URL || 'https://fullnode.testnet.sui.io:443';

// `localnet` is registered up front but only constructible under `devstack up` —
// outside devstack the default network is `testnet` and nothing switches to it.
// Under devstack, the Vite plugin injects and registers the dev wallet on the
// page (wallet-standard auto-discovery — no walletInitializers needed); it
// reports `sui:localnet` chains, so dApp Kit must default to `localnet` to
// connect on the same chain. Connecting is a user action (the dev wallet no
// longer auto-connects); e2e drives it via the devstack test bridge below.
export const dAppKit = createDAppKit({
  networks: ['testnet', 'localnet'] as const,
  defaultNetwork: isDevstack && devstackNetwork ? 'localnet' : 'testnet',
  createClient(network) {
    if (network === 'localnet') {
      if (!devstackNetwork) {
        throw new Error('The localnet network is only available under a devstack run');
      }
      return new SuiGrpcClient({ network: 'localnet', baseUrl: devstackNetwork.rpcUrl });
    }
    return new SuiGrpcClient({ network: 'testnet', baseUrl: TESTNET_GRPC_URL });
  },
});

// Register this dApp Kit instance with the devstack test bridge so Playwright's
// `connectAs` helper can drive a real wallet connection during e2e. Gated on a
// devstack dev run; the dynamic import keeps the incubation dep out of normal
// builds (the chunk is emitted but never loaded).
if (isDevstack && import.meta.env.DEV) {
  void import('@mysten-incubation/devstack/dapp-kit').then(({ registerDAppKitForTesting }) =>
    registerDAppKitForTesting(dAppKit),
  );
}

declare module '@mysten/dapp-kit-react' {
  interface Register {
    dAppKit: typeof dAppKit;
  }
}

/**
 * Sign and execute a transaction via the connected wallet, throwing on failure.
 * dApp Kit returns a `$kind` union instead of throwing when the transaction
 * fails on-chain, so call sites that treat resolution as success go through this.
 *
 * Also waits for the fullnode to index the transaction before resolving —
 * callers read back the state they just changed (permissions, members, group
 * objects), and reads lag execution until indexing completes.
 */
export async function signAndExecute({ transaction }: { transaction: Transaction }) {
  const result = await dAppKit.signAndExecuteTransaction({ transaction });
  if (result.$kind === 'FailedTransaction') {
    throw new Error(
      result.FailedTransaction.status.error?.message ?? 'Transaction failed on-chain',
    );
  }
  await dAppKit.getClient().waitForTransaction({ digest: result.Transaction.digest });
  return result;
}
