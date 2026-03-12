# Recovery Transport — Reference Implementation

This is a **reference implementation** of a read-only recovery transport that uses the [Discovery Indexer](https://github.com/MystenLabs/messaging-sdk-relayer/tree/main/walrus-discovery-indexer) and the Walrus aggregator to recover messages when the message backend is unavailable.

## How It Works

The reference relayer persists every message to Walrus as quilt patches (batched blobs). When the backend is unavailable, this transport recovers messages by:

1. **Querying the Discovery Indexer** for patch metadata (which blobs contain a group's messages)
2. **Filtering out DELETED patches** (no need to download deleted content)
3. **Grouping patches by blobId** for efficient batch reads from Walrus
4. **Downloading content from the Walrus aggregator** via the quilt patch API
5. **Converting** each message using the SDK's `fromWalrusMessage()` utility

The SDK client handles decryption automatically — the recovery transport just needs to deliver `RelayerMessage` objects.

## Usage

```ts
import { messagingGroups } from '@mysten/messaging-groups';
import { WalrusRecoveryTransport } from './walrus-recovery-transport.js';

const recovery = new WalrusRecoveryTransport({
  indexerUrl: 'http://localhost:3001',
  aggregatorUrl: 'https://aggregator.walrus-testnet.walrus.space',
});

// Plug it in as the transport — SDK handles decryption automatically
const client = messagingGroups({ transport: recovery, ... });
const { messages } = await client.getMessages({ groupRef: { groupId: '0x...' } });
```

## Building Your Own Recovery Transport

The SDK provides everything you need to build a custom recovery transport with your own indexer.

### What the SDK exports

| Export | Purpose |
|---|---|
| `RelayerTransport` | Interface your transport must implement (7 methods) |
| `RelayerTransportError` | Error class with HTTP status codes (use for 405/501 throws) |
| `fromWalrusMessage()` | Converts Walrus wire format → `RelayerMessage` |
| `WalrusMessageWire` | Type for the raw Walrus JSON shape |
| `RelayerMessage`, `FetchMessagesParams`, etc. | All param/result types |
| `HttpClientConfig` | Base config type (timeout, fetch override, onError) |
| `DEFAULT_HTTP_TIMEOUT` | Standard timeout (30s) |
| `HttpTimeoutError` | Timeout error class |

### 1. Implement `RelayerTransport`

```ts
import {
  RelayerTransportError,
  fromWalrusMessage,
  type RelayerTransport,
  type FetchMessagesParams,
  type FetchMessagesResult,
  type RelayerMessage,
  type WalrusMessageWire,
  // ... other param types as needed
} from '@mysten/messaging-groups';

class MyRecoveryTransport implements RelayerTransport {
  async fetchMessages(params: FetchMessagesParams): Promise<FetchMessagesResult> {
    // 1. Query YOUR indexer for message locations
    // 2. Download content from Walrus
    // 3. Convert using fromWalrusMessage()
    // 4. Return sorted by order
  }

  // Write operations — throw 405 (recovery is read-only)
  async sendMessage() { throw new RelayerTransportError('Read-only', 405); }
  async updateMessage() { throw new RelayerTransportError('Read-only', 405); }
  async deleteMessage() { throw new RelayerTransportError('Read-only', 405); }

  // Optional: single message fetch — throw 501 if not supported
  async fetchMessage() { throw new RelayerTransportError('Not supported', 501); }

  // One-shot subscribe: yield current messages, then complete
  async *subscribe(params) {
    const { messages } = await this.fetchMessages(params);
    for (const msg of messages) yield msg;
  }

  disconnect() {} // No-op for recovery
}
```

### 2. Use `fromWalrusMessage()` to convert Walrus blobs

The reference relayer stores messages on Walrus as raw JSON (via `serde_json::to_vec()`). The SDK exports a converter that handles the format differences:

```ts
import { fromWalrusMessage } from '@mysten/messaging-groups';
import type { WalrusMessageWire, RelayerMessage } from '@mysten/messaging-groups';

// Read blob content from Walrus (however you get it)
const rawJson = await readFromWalrus(blobId, patchId);
const wire: WalrusMessageWire = JSON.parse(rawJson);

// Convert to the SDK's RelayerMessage format
const message: RelayerMessage = fromWalrusMessage(wire);
```

`fromWalrusMessage()` handles:
- `number[]` -> `Uint8Array` for encrypted_msg/nonce
- ISO 8601 -> unix seconds for timestamps
- Deriving `isEdited` / `isDeleted` from timestamps and sync_status
- Field name mapping (Rust naming -> SDK naming)

### 3. Inject your transport

```ts
const client = messagingGroups({ transport: myRecoveryTransport, ... });
```

## Limitations

- **Read-only** — write methods throw 405
- **No single message fetch** — `fetchMessage()` throws 501 (indexer has no by-messageId lookup)
- **No attachment content** — Walrus stores attachment patch IDs, not full Attachment objects
- **One-shot subscription** — `subscribe()` yields current messages then completes (no polling)
