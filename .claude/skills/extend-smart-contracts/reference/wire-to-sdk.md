# After publishing — wire to the SDK

After publishing, expose your package as a `$extend()` SDK extension layered on top of `suiStackMessaging`.

The TS SDK is composed via the Sui client extension system (`$extend()`). The recommended pattern is to define your own extension on top of `suiStackMessaging`, mirroring how `suiStackMessaging` itself sits on top of `suiGroups` + `seal`.

```ts
// In your lightweight SDK: ship a single extension factory.
// my-messaging-ext-sdk/src/index.ts

import type { ClientWithExtensions } from '@mysten/sui/client';
import type { SuiStackMessagingClient } from '@mysten/sui-stack-messaging';

export function myMessagingExt(options: { packageId: string }) {
  return {
    name: 'myMessagingExt' as const,
    register: (client: ClientWithExtensions<{ messaging: SuiStackMessagingClient }>) => ({
      // Build txs that call your custom Move entry functions, reusing the
      // messaging client for things like envelope encryption / relayer access.
      paidJoin: async (groupUuid: string, payment: /* ... */) => { /* ... */ },
    }),
  };
}
```

Consumers then chain it after `suiStackMessaging`:

```ts
const client = new SuiGrpcClient({ network: "testnet" })
  .$extend(
    suiGroups({ witnessType: `${pkg}::messaging::Messaging` }),
    seal({
      /* ... */
    }),
  )
  .$extend(
    suiStackMessaging({
      /* ... */
    }),
  )
  .$extend(myMessagingExt({ packageId: MY_EXT_PACKAGE_ID }));

await client.myMessagingExt.paidJoin(groupUuid, payment);
await client.messaging.sendMessage({
  /* ... */
}); // canonical SDK still available
```

Why this beats a fork:

- You inherit the messaging client's encryption, relayer transport, and recovery flows for free.
- Consumers compose your extension with any future canonical SDK release without re-vendoring.
- The canonical SDK auto-detects `sui_stack_messaging` package IDs on testnet/mainnet (`TESTNET_SUI_STACK_MESSAGING_PACKAGE_CONFIG` / `MAINNET_SUI_STACK_MESSAGING_PACKAGE_CONFIG` in `ts-sdks/packages/sui-stack-messaging/src/constants.ts`) — your extension only needs to know its own package ID.

For trivial cases (a single tx call from app code), you can skip the extension and just build the transaction inline with `Transaction` from `@mysten/sui/transactions`.

References:

- Client extension system reference: `docs/sui-stack-messaging/Setup.md` ("Manual setup" section).
- The `suiStackMessaging` extension itself is a worked example of the pattern: `ts-sdks/packages/sui-stack-messaging/src/client.ts`.
- Mysten SDK building guidelines: https://sdk.mystenlabs.com/sui/sdk-building (linked from the root README).
