# Installation


## Prerequisites

<Tabs className="tabsHeadingCentered--small">
<TabItem value="prereq" label="Prerequisites">

- [x] Node.js >= 22
- [x] pnpm >= 10.17.0

</TabItem>
</Tabs>

- Node.js >= 22
- pnpm >= 10.17.0

```bash
pnpm add @mysten/sui-stack-messaging @mysten/sui-groups @mysten/seal @mysten/sui @mysten/bcs
```

The last four are peer dependencies. If your project already depends on them, you only need:

```bash
pnpm add @mysten/sui-stack-messaging @mysten/sui-groups
```

### Peer dependency versions

| Package | Minimum version |
| --- | --- |
| `@mysten/sui-groups` | \* |
| `@mysten/seal` | ^1.1.0 |
| `@mysten/sui` | ^2.6.0 |
| `@mysten/bcs` | ^2.0.2 |



## Build from source

```bash
git clone https://github.com/MystenLabs/sui-stack-messaging.git
cd sui-stack-messaging/ts-sdks
pnpm install
pnpm build
```

## Smart contracts

The messaging Move package is pre-deployed on Testnet and on Mainnet. The SDK auto-detects the correct package IDs based on the client's network.

For localnet or custom deployments, you must deploy both the `sui_groups` and `sui_stack_messaging` packages (`sui_stack_messaging` depends on `sui_groups`). Refer to the [Sui Groups Installation guide](https://github.com/MystenLabs/sui-groups) for deploying the base package first, then deploy the messaging package on top.

Provide a `packageConfig` when instantiating the client to point at your custom deployment. See [Setup](./Setup.md) for details.

## Relayer

The SDK communicates with an offchain relayer for message storage and delivery. See [Relayer](./Relayer.md) for integration details and the [relayer README](../../relayer/README.md) for running the reference implementation.
