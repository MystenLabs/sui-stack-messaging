# Extension pattern 3 — custom permission type

Extension pattern 3: declare, grant, and enforce a custom permission type across Move, the SDK, and the relayer.

Use case: "I want a `Moderator` role that can delete but not edit."

Before writing any Move, ask whether you actually need a _new_ permission witness. The four canonical messaging permissions (`MessagingSender`, `MessagingReader`, `MessagingEditor`, `MessagingDeleter`) compose freely — a "moderator who can delete but not edit" is just `MessagingDeleter` granted without `MessagingEditor`. That requires no new Move at all; you grant subsets via the `@mysten/sui-groups` TS SDK.

If you do need a brand new permission type, the work splits across three layers:

## 1. Declare the witness type (Move, minimal)

A permission witness is just a phantom marker struct. It must live in a published Move module — types can't be invented at runtime — but the module can be a one-liner in your extension package:

```move
module my_ext::roles;

public struct Moderator() has drop;
```

Publish with `sui client publish`. Note the package ID; that's all the on-chain footprint you need.

## 2. Grant / revoke via the sui-groups TS SDK

You do **not** need custom Move for granting. The canonical `permissioned_group` module is exposed by the `@mysten/sui-groups` extension, which is already chained on the messaging client (`suiStackMessaging` requires `suiGroups` upstream). The chain is:

```ts
const client = new SuiClient({ url })
  .$extend(
    suiGroups({ witnessType: `${MESSAGING_PKG}::messaging::Messaging` }),
    seal({
      /* ... */
    }),
  )
  .$extend(
    suiStackMessaging({
      /* ... */
    }),
  );

// Now both namespaces are available on the same client:
//   client.groups   — sui-groups SDK (permissions, members)
//   client.messaging — sui-stack-messaging SDK
```

The witness type is fixed at extension creation, so `client.groups` is bound to `Messaging`. Per-call options carry only the _permission_ type. To grant `Moderator`:

```ts
import { Transaction } from "@mysten/sui/transactions";

const tx = new Transaction();
tx.add(
  client.groups.call.grantPermission({
    groupId,
    member: memberAddr,
    permissionType: `${MY_EXT_PKG}::roles::Moderator`,
  }),
);
// ...sign and submit tx with the admin's signer.
```

The convenience layer `client.groups.tx.grantPermission({ transaction, ... })` and the top-level `await client.groups.grantPermission({ signer, ... })` (build + sign + submit) are also available — see the upstream `@mysten/sui-groups` package: [`MystenLabs/sui-groups`](https://github.com/MystenLabs/sui-groups) (`ts-sdks/packages/sui-groups/src/{call,transactions,client}.ts`).

The caller of this tx must hold `PermissionsAdmin` on the group (the creator does by default).

In Move, the equivalent is `group.grant_permission<Messaging, Moderator>(member_addr, ctx)` — the same method the `paid_join_rule` example uses to grant `FundsManager` (`paid_join_rule.move:188`).

## 3. Enforce the permission

This is the part that's easy to miss. Granting a custom permission stores it on-chain, but it doesn't gate anything by itself.

- **Off-chain enforcement (relayer)** — the reference relayer hard-codes the four canonical permissions in `relayer/src/auth/permissions.rs` and maps HTTP methods to them in `relayer/src/auth/middleware.rs:80–83`. A custom permission like `Moderator` is **not** recognized today; the relayer would either ignore it or reject the request depending on the operation. To enforce custom permissions on relayer endpoints, fork the relayer to extend the `MessagingPermission` enum and the method-to-permission mapping. See [`develop-relayer`](../../develop-relayer/SKILL.md).
- **On-chain enforcement** — only relevant if your custom permission gates Move-level behavior (e.g., a Move function in your extension package that should only run for moderators). Check with `group.has_permission<Messaging, Moderator>(ctx.sender())` from `sui-groups`, exactly like the `paid_join_rule` example checks `FundsManager` before withdrawal (`paid_join_rule.move:266`).

The canonical messaging permissions remain untouched in either case — your custom type lives alongside them.
