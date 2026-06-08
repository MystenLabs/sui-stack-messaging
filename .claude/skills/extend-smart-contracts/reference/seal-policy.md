# Extension pattern 1 — custom Seal policy

Extension pattern 1: a custom Seal policy (subscription / token-gated reader), with the Move shape and the client-side `SealPolicy` wiring.

Use case: "only paid subscribers can read this group's messages."

Pattern: declare an `entry fun seal_approve` (visibility is just `entry`, not `public entry`) in your package. Seal key servers call this function via dry-run during decryption. It takes Seal-injected `id: vector<u8>` first, your custom proof objects, then the canonical messaging objects (`PermissionedGroup<Messaging>`, `EncryptionHistory`), `Clock`, and `&TxContext`. Always start the body with `sui_stack_messaging::seal_policies::validate_identity(group, encryption_history, id)` to enforce the standard identity-bytes contract, then add your custom checks.

References:

- Move source: `move/packages/example_app/sources/custom_seal_policy.move`.
- Design doc: `move/design_docs/example_app/custom_seal_policy.md`.
- Working integration test (full Move + TS flow against localnet): `ts-sdks/packages/sui-stack-messaging/test/integration/localnet/custom-seal-policy.test.ts`.

Shape (mirrors the example):

```move
module my_ext::token_gated_policy;

use sui_groups::permissioned_group::PermissionedGroup;
use sui_stack_messaging::messaging::Messaging;
use sui_stack_messaging::encryption_history::EncryptionHistory;
use sui_stack_messaging::seal_policies;
use sui::clock::Clock;

const ENoAccess: u64 = 1;

entry fun seal_approve_subscription<Token: drop>(
    id: vector<u8>,
    sub: &Subscription<Token>,                      // your custom proof
    service: &Service<Token>,                       // your custom context
    group: &PermissionedGroup<Messaging>,
    encryption_history: &EncryptionHistory,
    clock: &Clock,
    ctx: &TxContext,
) {
    // 1. Reuse standard identity validation:
    //    - id parses as [group_id (32 bytes)][key_version (8 bytes LE u64)]
    //    - group_id in id matches `group`
    //    - encryption_history belongs to `group`
    //    - key_version exists in encryption_history
    seal_policies::validate_identity(group, encryption_history, id);

    // 2. Your custom checks (membership, subscription validity, etc.).
    assert!(check_policy(sub, service, group, clock, ctx), ENoAccess);
}
```

Notes:

- Visibility is `entry` (no `public`)
- Identity bytes are the standard format `[group_id (32)][key_version (8 LE u64)]`, produced by the SDK. Don't invent a custom layout — `validate_identity` enforces it.

## Wire it client-side via `SealPolicy`

Custom `seal_approve` functions are wired to the SDK through the `SealPolicy<TApproveContext>` interface — **not** as a `$extend()` extension. Pass an instance under `encryption.sealPolicy` at client creation; otherwise `DefaultSealPolicy` (which targets the canonical `seal_policies::seal_approve_reader`) is used.

The interface has two members (`ts-sdks/packages/sui-stack-messaging/src/encryption/seal-policy.ts`):

- `readonly packageId: string` — your extension package's original (V1) package ID. Becomes the Seal encryption namespace (instead of the messaging package's).
- `sealApproveThunk(identityBytes, groupId, encryptionHistoryId, ...context)` — returns a `(tx) => tx.moveCall({...})` thunk. Seal's key servers dry-run the resulting tx during decryption to authorize access.

The optional `TApproveContext` generic carries any extra runtime IDs your `seal_approve` needs (e.g., subscription / service / NFT). When set, `approveContext` becomes a required parameter on `sendMessage`, `getMessages`, etc., and the SDK threads it through to your thunk.

Sketch:

```ts
import type { SealPolicy } from "@mysten/sui-stack-messaging";
import type { Transaction, TransactionResult } from "@mysten/sui/transactions";

interface SubContext {
  serviceId: string;
  subscriptionId: string;
}

class SubscriptionSealPolicy implements SealPolicy<SubContext> {
  readonly packageId = MY_EXT_PACKAGE_ID;

  sealApproveThunk(
    identityBytes,
    groupId,
    encryptionHistoryId,
    context: SubContext,
  ) {
    return (tx: Transaction): TransactionResult =>
      tx.moveCall({
        target: `${MY_EXT_PACKAGE_ID}::token_gated_policy::seal_approve`,
        typeArguments: ["0x2::sui::SUI"],
        arguments: [
          tx.pure.vector("u8", identityBytes),
          tx.object(context.subscriptionId),
          tx.object(context.serviceId),
          tx.object(groupId),
          tx.object(encryptionHistoryId),
          tx.object("0x6"), // Clock
        ],
      });
  }
}

const client = createSuiStackMessagingClient<SubContext>(baseClient, {
  encryption: {
    sessionKey: { signer },
    sealPolicy: new SubscriptionSealPolicy(),
  },
  relayer: { relayerUrl: "..." },
});

await client.messaging.sendMessage({
  signer,
  groupRef: { uuid: "my-group" },
  text: "Hello!",
  approveContext: { serviceId: "0x...", subscriptionId: "0x..." },
});
```

References:

- Full walk-through with both Move + TS sides: `docs/sui-stack-messaging/Extending.md` ("Custom Seal Policy" section).
- Interface definition + JSDoc: `ts-sdks/packages/sui-stack-messaging/src/encryption/seal-policy.ts`.
- Default implementation as a worked example: `DefaultSealPolicy` in the same file.
- Where the policy is plugged into the encryption pipeline: `ts-sdks/packages/sui-stack-messaging/src/encryption/envelope-encryption.ts`.
