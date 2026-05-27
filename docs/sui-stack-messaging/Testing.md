# Testing

## SDK tests

All commands run from `ts-sdks/packages/sui-stack-messaging/`:

```bash
# Unit tests + type checking
pnpm test

# Unit tests only
pnpm test:unit

# Type checking only
pnpm test:typecheck
```

### Unit tests

Unit tests use Vitest with mocked dependencies (`SealClient`, `StorageAdapter`, `SuiClient`). No network access required.

Coverage includes:
- Envelope encryption (encrypt or decrypt, AAD, nonce handling)
- DEK manager (generation, caching, TTL)
- Session key manager (tier 1/2/3 flows)
- Seal policy (default policy, identity encoding)
- Sender verification (signature creation and validation)
- Attachments manager (upload, resolve, validation, edit flow)
- Walrus HTTP storage adapter (upload or download, error handling)
- HTTP transport (request signing, header construction)
- Derive (UUID to object ID derivation)
- TTL map (expiry, lazy eviction)
- Client (method delegation, error handling)

### Integration tests (Localnet)

Onchain tests against a local Sui node. No relayer required. Uses testc ontainers to spin up Sui local network and publishes Move packages automatically.

```bash
pnpm test:integration
```

Requires Docker. The setup bootstraps a local Sui node, funds an admin account, and publishes both `sui_groups` and `sui_stack_messaging` packages.

Coverage includes:
- Group creation, sharing, and configuration
- Metadata operations (set name, insert or remove data)
- View methods (membership, permissions, encryption history)
- Archive flow (pause and burn `UnpauseCap`)
- Paid join rule (example app integration)
- Custom Seal policy (example app integration)

### E2E tests (Testnet)

Full end-to-end tests against Sui Testnet with a live relayer. Tests the complete flow including encryption, relayer communication, Walrus archival, and message recovery.

```bash
# Run against testnet (default)
pnpm test:e2e

# Explicitly specify testnet
pnpm test:e2e:testnet
```

#### Required environment variables

| Variable | Description |
|----------|-------------|
| `TEST_WALLET_PRIVATE_KEY` | Funded Testnet wallet (`suiprivkey1...`) |

#### Optional environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SUI_RPC_URL` | Testnet fullnode | Sui RPC endpoint |
| `RELAYER_URL` | (starts container) | Pre-deployed relayer URL |
| `INDEXER_URL` | (starts container) | Pre-deployed indexer URL |
| `SEAL_KEY_SERVERS` | Testnet defaults | Comma-separated Seal key server IDs |
| `SEAL_THRESHOLD` | 2 | Seal threshold |
| `WALRUS_PUBLISHER_SUI_ADDRESS` | (none) | Walrus publisher filter for indexer |

Coverage includes:
- Message CRUD (send, get, edit, delete)
- Pagination and edge cases
- Multi-group messaging
- Permission-specific access control
- Encryption (key rotation, multi-version decrypt)
- Walrus sync (archival lifecycle)
- Recovery transport (message recovery from Walrus)
- Load testing

## Relayer tests

All commands run from `relayer/`:

```bash
# All tests (unit + integration, no network required)
cargo test

# Specific test suite
cargo test --test auth_integration_test
cargo test --test membership_sync_test
cargo test --test walrus_sync_test

# Walrus integration tests (requires testnet access, ignored by default)
cargo test --test walrus_integration_test -- --ignored
```

| Test suite | What it covers |
|-----------|----------------|
| `auth_integration_test` | Full auth pipeline for all 3 signature schemes, permission checks, replay protection, ownership enforcement |
| `membership_sync_test` | gRPC event subscription, membership cache updates, event parsing (uses mock gRPC server) |
| `walrus_sync_test` | Background sync lifecycle, batching, status transitions, cross-group batching (uses wiremock) |
| `walrus_integration_test` | Walrus HTTP client against real Testnet (ignored in CI) |

See the [relayer README](../../relayer/README.md) for detailed test descriptions.

## Move contract tests

Run from `move/packages/sui_stack_messaging/`:

```bash
sui move test
```
