# Build, test, and publish

Build and test commands for your extension package, plus the publish safety checklist.

## Build & test

```bash
# Build messaging (canonical) — usually only needed for codegen
sui move build --path move/packages/sui_stack_messaging
sui move test  --path move/packages/sui_stack_messaging

# Build & test the example extension package
sui move build --path move/packages/example_app
sui move test  --path move/packages/example_app

# Build & test your own package (same flags, your path)
sui move build --path /path/to/my_messaging_extension
sui move test  --path /path/to/my_messaging_extension
```

Move edition: `2024`.

For a broader index of runnable usage examples (the full integration test suite, plus baseline / view / metadata / archive flows), see the "Runnable usage examples" section in the parent skill: [`develop-on-sui-stack-messaging`](../../develop-on-sui-stack-messaging/SKILL.md).

## Publish

> **Safety — read before running `sui client publish`.**
>
> Publishing a Move package is **irreversible and costs real SUI on the target network.** The package ID is permanent, mined into every transaction that references it, and gets baked into your downstream TypeScript config (`packageConfig.messaging.originalPackageId` / `latestPackageId`) — there is no "unpublish." On mainnet, mistakes cost real money and have to be worked around with a fresh publish + downstream config changes.
>
> Pre-publish checklist — run these and read the output before invoking `publish`:
>
> ```bash
> sui client active-env       # confirm: testnet (NOT mainnet) for a dev publish
> sui client active-address   # confirm: this is your DEV deployer, not a multisig / treasury
> sui client gas              # confirm: enough SUI for the gas budget below
> sui move build --path /path/to/my_messaging_extension          # confirm: clean build
> sui move test  --path /path/to/my_messaging_extension          # confirm: tests pass
> ```
>
> Then publish — the `--dry-run` flag is your friend the first time on any network:
>
> ```bash
> # Dry-run first — no on-chain effect; surfaces gas + abort errors before they cost SUI.
> sui client publish --gas-budget 200000000 --dry-run /path/to/my_messaging_extension
>
> # Real publish (testnet recommended for first iterations):
> sui client publish --gas-budget 200000000 /path/to/my_messaging_extension
> ```
>
> Capture the printed package ID from the transaction effects — you'll wire it into your app config. The CLI writes the deployed address into `Move.lock` (and `Published.toml` if you opt into automated address management; see Sui docs on `sui move manage-package`). **Commit `Move.lock` immediately after publish** so future builds resolve dependencies to the same address.
>
> Mainnet publish guidance:
>
> - Iterate on testnet until the package is stable and the downstream TypeScript integration is verified end-to-end. Mainnet should be the *last* network you publish to, not the first.
> - **Pin all git dependencies in `Move.toml` to a release tag or commit SHA, not `main`** (see the `[dependencies]` block in [`package-layout.md`](./package-layout.md) — the `sui_stack_messaging` example uses `rev = "main"`; replace with a release tag before mainnet publish). `main` can move between your testnet and mainnet publishes, producing two non-identical packages.
> - Use a deployer address whose private key is under appropriate custody for production (hardware wallet, multisig, controlled CI signer). Never publish to mainnet from `~/.sui/sui_config/sui.keystore` on a laptop unless that's an intentional choice for a small disposable package.
> - Expect to pay tens of SUI in gas for a non-trivial publish. Have headroom — running out mid-tx aborts.

The `publish/` directory in this repo is a **maintainer-only** helper used to publish the canonical `sui_stack_messaging` package. **Do not use it for your extension package** — use `sui client publish` directly or your own custom publishing scripts.
