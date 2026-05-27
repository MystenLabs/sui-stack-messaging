# Relayer

The relayer is an offchain delivery operator that receives encrypted messages from clients, stores them in a local storage backend (in-memory by default, with support for pluggable persistent backends), and serves them back on request. It never decrypts messages or manages keys. For the trust model and security properties, see [Security](./Security.md).

## What the relayer does

1. Authenticates every request by verifying a cryptographic signature against the sender's Sui wallet address.

2. Authorizes the action by checking that the sender holds the required permission (for example, `MessagingSender` for POST) in the target group, using an onchain-synced permission cache.

3. Stores the encrypted message in a local storage backend (in-memory by default; pluggable for persistent storage such as PostgreSQL).

4. Archives messages to Walrus in the background for decentralized backup and cross-device recovery.

5. Stays in sync with Sui through a gRPC subscription that listens for group membership events and updates the local permission cache in real time.

## SDK integration

The SDK communicates with the relayer through the `RelayerTransport` interface:

```typescript
interface RelayerTransport {
  sendMessage(params: SendMessageParams): Promise<SendMessageResult>;
  fetchMessages(params: FetchMessagesParams): Promise<FetchMessagesResult>;
  fetchMessage(params: FetchMessageParams): Promise<RelayerMessage>;
  updateMessage(params: UpdateMessageParams): Promise<void>;
  deleteMessage(params: DeleteMessageParams): Promise<void>;
  subscribe(params: SubscribeParams): AsyncIterable<RelayerMessage>;
  disconnect(): void;
}
```

The built-in `HTTPRelayerTransport` connects to the reference relayer through HTTP polling. You can implement a custom transport for WebSocket, SSE, or any other delivery backend. See [Extending](./Extending.md) for details.

### Configuration

```typescript
// Built-in HTTP transport
relayer: {
  relayerUrl: 'https://your-relayer.example.com',
  pollingIntervalMs: 3000,  // default
  timeout: 30000,           // default
  onError: (err) => console.error(err),
}

// Custom transport
relayer: {
  transport: myCustomTransport,  // implements RelayerTransport
}
```

## Reference relayer

The SDK ships with a reference relayer implementation written in Rust (Axum). It is intended as a starting implementation, and you should consider adding rails to better fit your reliability, security, and scalability goals. For applications that require verifiable delivery, consider deploying the relayer within [Nautilus](https://docs.sui.io/guides/developer/nautilus/).

The reference relayer is provided as an example implementation. Applications are expected to run their own relayer or integrate messaging delivery into their existing backend infrastructure.

Full documentation, API reference, configuration, and deployment instructions are in the [relayer README](../../relayer/README.md). Additional docs are available in the [relayer/docs/](../../relayer/docs/) folder.

### API endpoints

| Endpoint | Method | Permission | Description |
|----------|--------|------------|-------------|
| `/health_check` | GET | (none) | Liveness probe |
| `/messages` | POST | `MessagingSender` | Create a new message |
| `/messages` | GET | `MessagingReader` | Fetch a single message or paginated list |
| `/messages` | PUT | `MessagingEditor` | Update a message (owner only) |
| `/messages/:id` | DELETE | `MessagingDeleter` | Soft-delete a message (owner only) |

### Authentication

Every request (except `/health_check`) must include:

- `X-Signature`: hex-encoded 64-byte signature
- `X-Public-Key`: hex-encoded public key with scheme flag prefix (Ed25519, Secp256k1, Secp256r1)

The relayer verifies the signature, derives the Sui address from the public key, confirms it matches the claimed sender, and checks the local permission cache. See the [relayer README](../../relayer/README.md) for the full verification pipeline.

### Membership sync

The relayer maintains a local permission cache by subscribing to Sui checkpoints through gRPC. It processes four event types from the Groups SDK contract:

| Event | Effect |
|-------|--------|
| `MemberAdded` | Adds member to cache (no permissions yet) |
| `MemberRemoved` | Removes member and all their permissions |
| `PermissionsGranted` | Adds specific permissions for a member |
| `PermissionsRevoked` | Removes specific permissions for a member |

This means the relayer reads onchain state but never writes to it.

### Walrus archival

The relayer archives messages to Walrus in the background, batching them into quilts. This enables cross-device message recovery without requiring centralized backups. Archival is triggered by either a timer (default: 1 hour) or a message count threshold (default: 50 new messages).

Walrus is used for durability and recovery, not real-time message delivery.

Messages follow a sync status lifecycle:

```
New message   --> SYNC_PENDING   --> SYNCED
Edited        --> UPDATE_PENDING --> UPDATED
Deleted       --> DELETE_PENDING --> DELETED
```

See [Archive and Recovery](./ArchiveRecovery.md) for the full archival and recovery pipeline.

### Walrus discovery indexer

The SDK also includes a reference `walrus-discovery-indexer` service that watches `BlobCertified` events on Walrus, inspects blobs for messaging patches, and serves a REST API for message recovery:

```
GET /v1/groups/:groupId/patches
```

This allows clients to recover messages when needed, or load messages across devices without having to configure backups to costlier and centralized storage systems. The `RecoveryTransport` interface in the SDK connects to this indexer. See [Extending](./Extending.md) for implementing a custom recovery transport.

### Storage

The reference relayer uses a pluggable `StorageAdapter` trait (Rust). The default backend is in-memory (all data lost on restart). A PostgreSQL adapter can be implemented against the same trait for durable persistence.

### Running the relayer

```bash
# With cargo
cd relayer
cp .env.example .env  # fill in SUI_RPC_URL and GROUPS_PACKAGE_ID
cargo run

# With Docker
docker compose up
```

### Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SUI_RPC_URL` | (required) | Sui fullnode gRPC URL |
| `GROUPS_PACKAGE_ID` | (required) | Deployed Groups SDK package ID |
| `PORT` | `3000` | HTTP server port |
| `REQUEST_TTL_SECONDS` | `300` | Timestamp validity window for replay protection |
| `WALRUS_PUBLISHER_URL` | Testnet publisher | Walrus publisher endpoint |
| `WALRUS_AGGREGATOR_URL` | Testnet aggregator | Walrus aggregator endpoint |
| `WALRUS_STORAGE_EPOCHS` | `5` | Walrus storage duration in epochs |
| `WALRUS_SYNC_INTERVAL_SECS` | `3600` | Seconds between timer-based sync cycles |
| `WALRUS_SYNC_BATCH_SIZE` | `100` | Max messages per Walrus sync batch |
| `WALRUS_SYNC_MESSAGE_THRESHOLD` | `50` | New message count that triggers immediate sync |

See the [relayer README](../../relayer/README.md) for the full configuration reference, project structure, testing instructions, and deployment options.
