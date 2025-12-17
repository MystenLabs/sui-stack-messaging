# Messaging SDK V2

In the revised Messaging SDK architecture, we aim to move the messaging capabilities to an off-chain relayer service.
Sending & retrieving messages, archiving & syncing messaging history will all be moved off-chain.
We will be offering an example implementation of such a service with and without Nautilus.

The smart contract should only deal with Groups & fine-grained permissions, as well as integration with Seal.
It was also considered beneficial to offer a standalone generic Groups&Permissions smart contract as a reusable library.

## High Level Requirements

- Keeping track of member permissions
- Add/remove members
- leave_group
- join_group ??
- Grant/revoke permissions
- Check membership status (is someone a member of a group?)
- Authorize an action / check if a member has a specific permission
- The end-user should be able to keep track of their group memberships.
- Support for custom implementations of `seal_approve`

NOTE: We want to avoid doing frequent transactions, so, having to execute 1 tx each time someone wants to send a message
is prohibited. (This also makes the “Typed Witness” Auth<T, Perm> token pattern prohibitive for checking “SendMessagePermission”)
Could we follow a strategy similar to seal? (Dry-run or dev-inspect the “is_authorized” function?)
!! Only an issue for “SendMessagePermission”.

### Messaging permissions:

(These could be part of groups)

- AddMember
- RemoveMember
- GrantPermission
- RevokePermission

- SendMessage
- ReadMessage (I guess this is tied to Seal)
- EditMessage
- DeleteMessage

- RotateEncryptionKey

### Customization support

In general, we need a mechanism to allow custom gating. This could be done either by a `join` function that allows custom policies
Or via a custom `seal_approve`, or maybe even a combination of both.
Example custom use cases:

- token-gating (Pay to gain access)
- Time-limited private groups that become public after the gating window
- Subscription system (pay to gain access for X days)

### Seal namespace (identity-bytes) strategy:

For default seal_approve (in messaging package):

- Namespace: [creator_address (32 bytes)][nonce]
- Rationale: Creator address is known before tx execution, enabling single-PTB group creation

For custom seal_approve (in 3rd-party package):

- Namespace: Defined by the custom contract (e.g., [service_id][nonce])
- The custom package's ID is used for Seal encryption

## Open Questions / Discussion Points

- join_group: We would need to support a custom policy for joining? Could we defer that to a 3rdparty app-contract implementation ?could be also done as JoinRequest ticket, and similarly InvitationRequest. How can we support this. Maybe we can offer something similar to the TransferPolicy pattern?
- What makes this customization even trickier, is the requirement to build a Typescript SDK as well. How could we make the Typescript SDK extensible?I believe the only option is to allow customization only through custom `seal_approve` contracts. In this case, the ts-sdk would simply ask for the custom seal_approve contract pkgID
- Another potential approach to allow customization would be to have the MessagingGroup as `key+store`, so that a 3rdparty contract can just wrap it, and basically offer custom wrappers for all functions. Would require a lot of boilerplate, and would probably make the ts-sdk unusable for them though.
- MemberCap vs address ? Tricky due to Groups being a generic library.
- Individual user’s groups memberships tracking? Derived-objects would help for deduplication, but not for discovery. User would still need to know the MessagingGroup IDs they are a member of

## Smart Contracts

Layer 1: groups

Meant as a generic reusable library

- PermissionsGroup struct (has `store`, can be embedded)
- Generic permission witnesses via TypeName
- Core: add/remove member, grant/revoke permission, has_permission

Layer 2: messaging

Wrapper on top of the groups library

- MessagingGroup struct (has `key`, is a Sui object)
- Messaging-specific permissions: Sender, Reader, Deleter, Editor, EncryptionKeyRotator
- EncryptionHistory for key versioning (attached via dynamic field)
- Default seal_approve implementations (seal_approve_member, seal_approve_reader)

Layer 3: Custom app contracts

Third-party Builders implement custom seal_approve functions in their contract, and link them with the messaging contract & ts-dk

- Example app: subscription-based access with membership + expiry checks
