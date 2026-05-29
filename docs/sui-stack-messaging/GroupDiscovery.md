# Group Discovery


This document covers how to discover which groups a user belongs to, and how to track the UUIDs that the SDK uses for deterministic group addressing.

The alpha SDK used owned `MemberCap` objects: when a user joined a group, they received a `MemberCap` transferred to their address. Clients could query "all objects owned by me of type `MemberCap`" to discover their groups.

The current architecture uses a permissions-as-membership model: a member exists if and only if they hold at least one permission in the group's onchain `PermissionsTable`. There is no owned object to query. Instead, all membership changes emit typed events, which can be queried through GraphQL or processed by an indexer.

## Discovery approaches

### GraphQL event queries (no infrastructure required)

The `sui_groups` contract emits `MemberAdded<T>` and `MemberRemoved<T>` events on every membership change. You can query these through Sui GraphQL to compute a user's current group memberships.

```graphql
query DiscoverGroups($eventType: String!, $cursor: String) {
  events(filter: { eventType: $eventType }, first: 50, after: $cursor) {
    pageInfo {
      hasNextPage
      endCursor
    }
    nodes {
      contents {
        json
      }
    }
  }
}
```

The event type strings are available from the SDK's BCS module:

```typescript
const memberAddedType = client.groups.bcs.MemberAdded.name;
const memberRemovedType = client.groups.bcs.MemberRemoved.name;
```

These produce fully-qualified type names like:

```
0x{packageId}::permissioned_group::MemberAdded<0x{messagingPkgId}::messaging::Messaging>
```

To compute the user's current groups:
1. Paginate through all `MemberAdded` events, filtering for the target address
2. Paginate through all `MemberRemoved` events, filtering for the target address
3. Compute the difference: `activeGroups = addedGroupIds - removedGroupIds`

The reference chat-app implements this pattern in [useGroupDiscovery.ts](../../chat-app/src/hooks/useGroupDiscovery.ts).

#### Limitations:
- Client-side filtering: GraphQL returns all events of the given type, and the client filters by address. For applications with many groups, this requires paginating through a large volume of events.

- No UUID in membership events: `MemberAdded` and `MemberRemoved` contain `group_id` and `member`, but not the UUID. To recover the UUID for discovered groups, make a follow-up call to `client.messaging.view.groupsMetadata({ groupIds })`.

- Eventual consistency: There can be a short delay between a membership change and the event appearing in GraphQL.

### Custom indexer (recommended for production)

For production applications, build a service that indexes membership events and maintains a queryable database. This is the most robust approach.

**Events to index:**

| Event | Fields | Action |
|-------|--------|--------|
| `MemberAdded<T>` | `group_id`, `member` | Insert membership row |
| `MemberRemoved<T>` | `group_id`, `member` | Delete membership row |
| `PermissionsGranted<T>` | `group_id`, `member`, `permissions[]` | Update permission set |
| `PermissionsRevoked<T>` | `group_id`, `member`, `permissions[]` | Update permission set |
| `EncryptionHistoryCreated` | `encryption_history_id`, `group_id`, `uuid` | Store UUID mapping |
| `GroupCreated<T>` | `group_id`, `creator` | Store group metadata |
| `GroupDeleted<T>` | `group_id`, `deleter` | Mark group as deleted |

A minimal indexer maintains a `(user_address, group_id) -> permissions[]` table and a `group_id -> uuid` mapping. Expose an API like:

```
GET /user/:address/groups -> [{ groupId, uuid, permissions }]
```

The relayer's `MembershipSyncService` already processes these events for permission checking through gRPC checkpoint subscription. A similar pattern can be used for group discovery. See the [relayer README](../../relayer/README.md) for the event processing approach.

## UUIDs and deterministic addressing

Each messaging group is created with a UUID (client-provided or SDK-generated). The UUID is used as a derivation key with `deriveObjectID()` to compute deterministic onchain addresses for both:

- `PermissionedGroup<Messaging>` (through `PermissionedGroupTag(uuid)`)
- `EncryptionHistory` (through `EncryptionHistoryTag(uuid)`)

Both objects are derived from the shared `MessagingNamespace`, so their addresses are predictable before the creation transaction executes. This enables single-transaction group creation: the group, encryption history, initial DEK, and Seal encryption can all happen in one PTB.

### The `GroupRef` pattern

Most SDK methods accept a `GroupRef`, either a UUID or explicit object IDs:

```typescript
// By UUID (recommended): derives both IDs internally
groupRef: { uuid: 'my-group-uuid' }

// By explicit IDs: when you already have the object addresses
groupRef: { groupId: '0x...', encryptionHistoryId: '0x...' }
```

Using UUIDs is simpler because the SDK derives both IDs from the UUID without RPC calls. The derivation is deterministic and produces the same addresses across all clients. See [Setup](./Setup.md) for more on the `GroupRef` pattern.

### Tracking UUIDs

The UUID is stored onchain in two places:
1. `EncryptionHistory.uuid` field
2. `Metadata.uuid` field (readable through `client.messaging.view.groupsMetadata()`)

It is also emitted in the `EncryptionHistoryCreated` event at group creation time.

However, you need to track UUIDs on the client side to avoid extra RPC calls on every operation. Options from simplest to most robust:

- `localStorage` or a local database: Store the UUID when you create a group. The reference `chat-app` does this in [group-store.ts](../../chat-app/src/lib/group-store.ts). 

- Extend your indexer: Index `EncryptionHistoryCreated` events to store the `uuid` alongside group membership data. This gives you `GET /user/:address/groups -> [{ groupId, uuid, ... }]` in a single call, and works across devices.

- Extend the relayer: Store `{ uuid, groupId, name }` tuples. Clients POST on group creation and GET on new device setup.

If you discover groups through events but don't have their UUIDs, you can always recover them from onchain state:

```typescript
const metadataMap = await client.messaging.view.groupsMetadata({ groupIds: [groupId] });
const metadata = metadataMap[groupId];
// metadata.uuid, metadata.name, metadata.creator, metadata.data
```

This batches into a single RPC call for multiple groups.

## SDK view helpers

Once you know a group's ID, the SDK provides read-only methods for querying membership and permissions:

```typescript
// Check if someone is a member
const isMember = await client.groups.view.isMember({ groupId, member: '0x...' });

// Check a specific permission
const canSend = await client.groups.view.hasPermission({
  groupId,
  member: '0x...',
  permissionType: `${pkgId}::messaging::MessagingSender`,
});

// List all members with their permissions
const { members, hasNextPage, cursor } = await client.groups.view.getMembers({
  groupId,
  exhaustive: true,  // fetch all pages
});

// Get group metadata (name, UUID, creator, custom data)
const metadataMap = await client.messaging.view.groupsMetadata({ groupIds: [groupId] });
const metadata = metadataMap[groupId];
```

See [API Reference](./APIRef.md) for the full list of view methods.

## Events reference

All events are parameterized by the witness type `T`, scoping them to your application. For the messaging SDK, `T` is `Messaging`.

**Permissioned-groups events:**

| Event | Fields | When |
|-------|--------|------|
| `GroupCreated<T>` | `group_id`, `creator` | Group created |
| `GroupDerived<T, K>` | `group_id`, `creator`, `parent_id`, `derivation_key` | Derived group created |
| `MemberAdded<T>` | `group_id`, `member` | First permission granted to a new member |
| `MemberRemoved<T>` | `group_id`, `member` | All permissions removed from a member |
| `PermissionsGranted<T>` | `group_id`, `member`, `permissions[]` | Permissions granted |
| `PermissionsRevoked<T>` | `group_id`, `member`, `permissions[]` | Permissions revoked |
| `GroupDeleted<T>` | `group_id`, `deleter` | Group deleted |
| `GroupPaused<T>` | `group_id`, `paused_by` | Group paused |
| `GroupUnpaused<T>` | `group_id`, `unpaused_by` | Group unpaused |

**Messaging events:**

| Event | Fields | When |
|-------|--------|------|
| `EncryptionHistoryCreated` | `encryption_history_id`, `group_id`, `uuid`, `initial_encrypted_dek` | Group created |
| `EncryptionKeyRotated` | `encryption_history_id`, `group_id`, `new_key_version`, `new_encrypted_dek` | Key rotated |
