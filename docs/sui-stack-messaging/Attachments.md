# Attachments

The SDK supports sending encrypted file attachments alongside messages. Each file is encrypted individually with the group's DEK, uploaded to a pluggable storage backend, and its encrypted metadata is stored inline with the message through the relayer. Attachments are entirely offchain: the Move contracts are unaware of them.

## Configuration

Attachment support requires a `StorageAdapter` at client creation:

```typescript
import {
  createMessagingGroupsClient,
  WalrusHttpStorageAdapter,
} from "@mysten/sui-stack-messaging";

const client = createMessagingGroupsClient(baseClient, {
  // ...
  attachments: {
    storageAdapter: new WalrusHttpStorageAdapter({
      publisherUrl: "https://publisher.walrus-testnet.walrus.space",
      aggregatorUrl: "https://aggregator.walrus-testnet.walrus.space",
      epochs: 5,
    }),
    maxAttachments: 10, // default
    maxFileSizeBytes: 10_485_760, // 10 MB default
    maxTotalFileSizeBytes: 52_428_800, // 50 MB default
  },
});
```

When omitted, `sendMessage` cannot include files and received attachment metadata is not resolvable. See [Setup](./Setup.md) for the full configuration reference.

## Encryption model

Attachments use the same group DEK as message text, but each file gets its own encryption:

```
+------------------------------------------------------------------+
|  Per file:                                                        |
|                                                                   |
|  file bytes --> AES-GCM encrypt --> encrypted file data + nonce   |
|                 (DEK + random nonce)                              |
|                                                                   |
|  metadata JSON --> AES-GCM encrypt --> encrypted metadata         |
|  (fileName,        (DEK + separate      + metadataNonce           |
|   mimeType,         random nonce)                                 |
|   fileSize,                                                       |
|   extras)                                                         |
+------------------------------------------------------------------+
```

Metadata is encrypted separately from file data. This allows clients to decrypt metadata (to display file name, type, and size) without downloading the full file content.

See [Encryption](./Encryption.md) for the underlying DEK management and AES-GCM details.

## Upload flow

When `sendMessage()` or `editMessage()` includes files:

1. **Validate**: Check file count and sizes against configured limits
2. **Encrypt each file**: Individually with the group DEK and a per-file random nonce
3. **Batch upload**: All encrypted files are uploaded to the `StorageAdapter` as a single batch (for example, one Walrus quilt containing multiple patches)
4. **Encrypt metadata**: For each file, a JSON blob containing `fileName`, `mimeType`, `fileSize`, and optional `extras` is encrypted with a separate nonce
5. **Build wire format**: Each file becomes an `Attachment` with `storageId`, `nonce`, `encryptedMetadata`, and `metadataNonce`
6. **Send to relayer**: The `Attachment[]` array is included in the relayer request alongside the encrypted message text

## Download flow (lazy)

When a message with attachments is received, the SDK decrypts the metadata immediately but defers file downloads:

1. **Decrypt metadata**: For each attachment, the encrypted metadata is decrypted to reveal `fileName`, `mimeType`, `fileSize`, and `extras`
2. **Create handles**: Each attachment becomes an `AttachmentHandle` with the decrypted metadata and a `data()` closure
3. **Lazy download**: Calling `handle.data()` triggers a download from the `StorageAdapter`, followed by decryption with the group DEK and the file's nonce

```typescript
for (const attachment of msg.attachments) {
  console.log(`${attachment.fileName} (${attachment.fileSize} bytes)`);

  // Download + decrypt on demand (not cached)
  const bytes = await attachment.data();
}
```

Each `data()` call triggers a fresh download and decryption. There is no attachment-level caching.

## Wire format

The `Attachment` type travels through the relayer:

```typescript
interface Attachment {
  storageId: string; // Storage backend ID (e.g., Walrus quilt-patch-id)
  nonce: string; // Hex-encoded 12-byte AES-GCM nonce for file data
  encryptedMetadata: string; // Hex-encoded encrypted JSON metadata
  metadataNonce: string; // Hex-encoded 12-byte AES-GCM nonce for metadata
}
```

The relayer stores this array opaquely without interpreting the encrypted fields.

## Editing attachments

When editing a message, you can add, remove, or keep attachments:

```typescript
await client.messaging.editMessage({
  signer: keypair,
  groupRef: { uuid: "my-group" },
  messageId: "abc123",
  text: "Updated message",
  attachments: {
    current: originalMsg.attachments.map((a) => a.wire), // current Attachment[]
    remove: ["storage-id-to-remove"], // storageIds to remove
    new: [{ fileName: "new.pdf", mimeType: "application/pdf", data: pdfBytes }],
  },
});
```

The SDK computes the final attachment list as: `current - remove + upload(new)`. Removed files are deleted from the storage backend on a best-effort basis (silently skipped if the adapter doesn't support deletion).

## Built-in Walrus adapter

The `WalrusHttpStorageAdapter` uses the Walrus HTTP publisher and aggregator:

- **Upload**: `PUT /v1/quilts?epochs=N` with all files as a single quilt. Each file becomes a patch, and the adapter returns the quilt-patch-id as the `storageId`.
- **Download**: `GET /v1/blobs/by-quilt-patch-id/{id}` to fetch a single file by its patch ID.
- **Delete**: Not supported by the Walrus publisher HTTP API. Orphaned encrypted data expires naturally per Walrus retention policy.

## Custom storage adapters

Implement the `StorageAdapter` interface to use any storage backend. The adapter is encryption-unaware: it only handles opaque bytes. See [Extending](./Extending.md) for the interface definition and examples.


