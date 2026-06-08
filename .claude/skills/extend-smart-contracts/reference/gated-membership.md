# Extension pattern 2 — gated membership (Actor object pattern)

Extension pattern 2: paid or gated self-serve join, implemented with the actor-object pattern.

Use case: "users pay SUI to self-serve join the group."

Pattern: the **actor object pattern** — a shared object that holds delegated permissions on the group and exposes restricted operations to arbitrary callers. The actor's `&UID` is the authority token: the group's `object_grant_permission` API checks that the holder of that UID has the right permission, then performs the grant on the actor's behalf. End users never hold admin permissions directly; they interact with the actor.

Setup flow (mirrors `paid_join_rule.move`):

1. Admin creates a group via `messaging::create_group(...)`.
2. Admin creates the actor object (e.g. `PaidJoinRule<Token>`) — a `has key` object with a UID and any state it needs (fee, accumulated balance, etc.).
3. Admin grants `ExtensionPermissionsAdmin` to the actor's address:
   `group.grant_permission<Messaging, ExtensionPermissionsAdmin>(rule_address, ctx)`.
4. Actor is `transfer::share_object`'d so anyone can use it.
5. The actor's public `join` function takes payment, then grants `MessagingReader` (membership) to the sender by passing its own `&UID` as authority:
   `group.object_grant_permission<Messaging, MessagingReader>(&rule.id, ctx.sender())`.

Actor objects also appear inside the canonical messaging package itself: `group_leaver` (self-service leave without admin permission) and `group_manager` (SuiNS reverse lookup + metadata admin) follow the same shape.

References:

- Worked example: `move/packages/example_app/sources/paid_join_rule.move`.
- Design doc for this example: `move/design_docs/example_app/paid_join_rule.md`.
- Working integration test (full grant-permissions setup, payment, member-add flow against localnet): `ts-sdks/packages/sui-stack-messaging/test/integration/localnet/paid-join-rule.test.ts`.
- Pattern overview, including the canonical actors: `move/design_docs/REQUIREMENTS.md`.
- Canonical actors: `move/design_docs/sui_stack_messaging/group_leaver.md`, `move/design_docs/sui_stack_messaging/group_manager.md`.

Note:

You might want to implement a more comprehensive payment system than what the `paid_join_rule.move` example does.
`sui-payment-kit` might interest you: https://github.com/MystenLabs/sui-payment-kit
