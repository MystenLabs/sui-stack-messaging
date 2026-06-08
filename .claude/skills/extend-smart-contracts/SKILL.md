---
name: extend-smart-contracts
description: Use when the user wants to add custom Move modules on top of sui_stack_messaging — custom seal policies (subscription-based, token-gated), paid-join rules, custom permission types, or any extension package depending on the canonical messaging contracts. Trigger phrases - "custom seal policy", "paid join rule", "extend the messaging contracts", "add a Move module", "custom permission type", "token-gated messaging", "subscription messaging", "extend smart contracts".
---

# Extend the smart contracts

`move/packages/sui_stack_messaging/` is canonical and already published. **Do not fork it.** To add custom behavior, write your own Move package that depends on it, then wire that package to the canonical TypeScript SDK (via the `SealPolicy` interface or a `$extend()` extension). The repo ships two worked Move examples in `move/packages/example_app/`.

This `SKILL.md` is a router: it covers what's specific to extending `sui_stack_messaging` and points to the verbose walk-throughs in `reference/`. For general Move-language quality checks, the community-maintained [move-code-quality-skill](https://github.com/1NickPappas/move-code-quality-skill) is one option.

For canonical mainnet/testnet package IDs (`sui_stack_messaging` and `sui_groups`), see the "Canonical package addresses" section in the repo-root [CLAUDE.md](../../../CLAUDE.md) / [AGENTS.md](../../../AGENTS.md).

## What extending looks like

The shape is always the same:

1. Scaffold a **separate** Move package that adds a `[dependencies]` entry on `sui_stack_messaging` (and usually `sui_groups`). You never modify, re-publish, or fork the canonical package.
2. Write custom `entry` / `public` functions or a witness type against the canonical types — `PermissionedGroup<Messaging>`, `EncryptionHistory`, and the `Messaging*` permissions.
3. Publish your package with `sui client publish` (not the maintainer-only `publish/` helper).
4. Wire it to the SDK — either through the `SealPolicy` interface or as a `$extend()` extension layered on top of `suiStackMessaging`.

Start from `reference/package-layout.md` for the layout and a fresh-package skeleton.

## Which pattern do I need?

| If the use case is...                                       | Use                          | Reference                        |
| ----------------------------------------------------------- | ---------------------------- | -------------------------------- |
| "only paid subscribers / token holders can read this group" | Custom Seal policy           | `reference/seal-policy.md`       |
| "users pay SUI to self-serve join the group"                | Gated membership (actor obj) | `reference/gated-membership.md`  |
| "I want a new role like `Moderator`"                        | Custom permission type       | `reference/custom-permission.md` |

Decision notes:

- **Custom permission — first ask whether you need one.** The four canonical permissions (`MessagingSender`, `MessagingReader`, `MessagingEditor`, `MessagingDeleter`) compose freely. A "moderator who can delete but not edit" is just `MessagingDeleter` granted without `MessagingEditor` — no new Move at all. Only declare a new witness type when none of the canonical permissions express your role.
- **A Seal policy is client-side wiring, not a `$extend()` extension** — it plugs in via `encryption.sealPolicy`. The actor-object and permission patterns are pure Move plus the `@mysten/sui-groups` SDK.
- **Granting a custom permission enforces nothing by itself** — it only stores on-chain. You enforce it off-chain (fork the relayer) or on-chain (your own Move check). `reference/custom-permission.md` covers both.

## Reference files

- `reference/package-layout.md` — the `move/packages/` layout you build against, plus the skeleton for a fresh extension package (`Move.toml` deps, why no `[addresses]` block, pin your revs).
- `reference/seal-policy.md` — Extension pattern 1: custom Seal policy (subscription / token-gated reader); Move shape plus client-side `SealPolicy` wiring.
- `reference/gated-membership.md` — Extension pattern 2: paid / gated self-serve join via the actor-object pattern.
- `reference/custom-permission.md` — Extension pattern 3: declare, grant, and enforce a custom permission type across Move / SDK / relayer.
- `reference/build-and-publish.md` — build & test commands and the publish safety checklist (irreversible, costs real SUI; testnet-first; pin deps).
- `reference/wire-to-sdk.md` — after publishing, expose your package as a `$extend()` SDK extension on top of `suiStackMessaging`.

## What NOT to do

- Do not fork `sui_stack_messaging` to add a new policy. Build a new package that depends on it. Forking puts you on a separate upgrade path from canonical.
- Do not redefine messaging permission types (`MessagingSender`, etc.) in your package. Add new types alongside.
- Do not edit `Published.toml` for the canonical package. It is committed and load-bearing for upgrade paths.
- Do not add an `[addresses]` block to your `Move.toml` — it flips your package to old-style and breaks the build against the new-style canonical package (details in `reference/package-layout.md`).
- Do not use the maintainer-only `publish/` helper for your extension — use `sui client publish` directly (details in `reference/build-and-publish.md`).

## Cross-links

- Extending guide (TS side, with Move snippets): `docs/sui-stack-messaging/Extending.md`.
- Move package architecture: `move/design_docs/REQUIREMENTS.md`.
- Per-module design docs: `move/design_docs/sui_stack_messaging/{messaging,seal_policies,encryption_history,group_leaver,group_manager,metadata,version}.md`.
- Worked examples: `move/design_docs/example_app/{custom_seal_policy,paid_join_rule}.md`.
- General Move quality check (community-maintained, optional): https://github.com/1NickPappas/move-code-quality-skill.
