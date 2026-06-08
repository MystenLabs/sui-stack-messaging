# Package layout and extension-package skeleton

The `move/packages/` layout you build your extension against, plus the skeleton for scaffolding a fresh extension package.

## Package layout you'll be working against

```
move/packages/
├── sui_stack_messaging/         CANONICAL — depend on, don't modify
│   └── sources/
│       ├── messaging.move           public entry; defines permission types
│       ├── seal_policies.move       seal_approve_reader entry; access control
│       ├── encryption_history.move  key versioning
│       ├── group_leaver.move        self-service leave
│       ├── group_manager.move       SuiNS / metadata admin
│       ├── metadata.move            VecMap key-value group metadata
│       └── version.move             package version gating
└── example_app/                 REFERENCE — copy-paste starting point
    └── sources/
        ├── custom_seal_policy.move  subscription-based reader policy
        └── paid_join_rule.move      payment-gated MessagingReader grant
```

The messaging package depends on `sui-groups` and operates on its types directly. Types like `PermissionedGroup<T>` and `PermissionsAdmin` come from `sui_groups::permissioned_group` and your extension package will `use` them from there too. At runtime, `messaging.move` creates `PermissionedGroup<Messaging>` instances via `permissioned_group::new_derived(...)`. The package adds its own messaging-specific permission witness types: `MessagingSender`, `MessagingReader`, `MessagingEditor`, `MessagingDeleter`, `MetadataAdmin`, `SuiNsAdmin`.

## Skeleton: a new extension package

Scaffold a fresh Move package with the Sui CLI, then add the messaging dependencies:

```bash
sui move new my_messaging_extension
cd my_messaging_extension
```

This creates `Move.toml`, `sources/`, and `tests/` with sensible defaults. Edit `Move.toml` to add the dependencies:

```toml
[package]
name = "my_messaging_extension"
edition = "2024"

[dependencies]
sui_stack_messaging = { git = "https://github.com/MystenLabs/sui-stack-messaging.git", subdir = "move/packages/sui_stack_messaging", rev = "main" }
sui_groups          = { git = "https://github.com/MystenLabs/sui-groups.git", subdir = "move/packages/sui_groups", rev = "ea766818b90e162341e885a855718388edcc8e99" } # tag mainnet/v1
```

**Pin a release tag or commit SHA — never `main` — before any mainnet publish.** The example above uses `rev = "main"` only for local prototyping; `main` can shift between a testnet and a mainnet publish, leaving you with two non-identical compiled packages. The `sui_groups` line shows the right shape — pin to a specific commit and label it (here: `tag mainnet/v1`). The `Sui` framework dependency is added automatically by `sui move new`.

**Don't add an `[addresses]` block** (a reflex from older Move tutorials). The canonical `sui_stack_messaging` is a new-style package — it resolves `suins` through an MVR `r.mvr` dependency — and adding `[addresses]` or `[dev-addresses]` flips your package to old-style, which fails the build with `Packages with old-style Move.toml files cannot depend on new-style packages`. Keep the manifest address-less, as `move/packages/example_app/Move.toml` does.
