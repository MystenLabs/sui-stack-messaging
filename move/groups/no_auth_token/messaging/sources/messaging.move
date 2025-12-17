// On-chain methods:
//
// - add_member
// - remove_member
// - grant_permission
// - revoke_permission
// (- authenticate action (return Auth<ActionPermission> token in auth_token_in_messaging package))
// - is_authorized
// - is_member
//
// - seal_approve (permission to decrypt messages)
// Does this need to be able to work with the `groups` smart-contract?
// This is supposed to support any type of app-specific gating-logic.
// So not sure if we want to bake this function in the messaging contract,
// or even on the `groups` contract.
// Maybe we could offer a default `seal_approve_member`, but leave any custom
// gating logic to be implemented by the app developer in their own contract?
// Would it perhaps make more sense to implement the `seal_approve_member` here
// and leave the gating logic to the `app_contract::add_member`/`app_contract::leave_group` functions?
//
// what about seal's identity-bytes, aka keys namespace?
// One case is to use the AuthState's UID (or perhaps MessagingGroup UID) + [nonce]
// or we can keep track of the creator address, and use [creator_address][nonce]
// the second approach makes it easier to work with envelope encryption
//
// There's still the problem of: do we want to implement a default `seal_approve`,
// and what needs to be done to support a custom `seal_approve` in an app-specific contract
// that makes use of the messaging contract?
// How should we deal with the identity-bytes in that case?
// Let's not forget we are also supposed to expose a ts-sdk, that should handle encryption/decryption
// as well. Should we just ask for the identity-bytes to be provided by the app-developer when initializing
// the messaging group ts-sdk?

//
// Would it make sense to think of the project as 2 OR 3 layers?
// 1) groups generic smart-contract
// 2) thin messaging contract on top of groups (expose the groups-permissions functionality + messaging-specific permissions?)
// 3) app-specific contract on top of messaging/groups, meant to implement custom gating logic? Should this be an expecation?
// what needs to be done on groups + messaging contracts, to allow for that?
// There are 2 cases to consider getting "overriden" by a custom app-contract using the messaging contract:
// - custom seal_approve functions
// - custom add_member function (e.g. paid-membership, invite-only, time-limited memberships, time-limited gating, etc)
// (so in this case seal just looks for membership, while custom-gating is handled by the custom add_member)

// Off-chain methods:
// - send_message (via message relayer service)
// We still want to authenticate that the sender has permission to send messages to the group
// BUT we don't want to execute a transaction for every message sent. That was the point
// of having off-chain messaging in the first place.
// Could we solve this by having the off-chain relayer do a dry-run/dev-inspect similar to seal's approach?
// The off-chain relayer needs to also:
// - retrieve & decrypt messages
// verify permission to read (I guess seal_approve is ok since it only does a dry-run, and can generally get cached?)
// - delete message(s)
// verify permission to delete (can we do similar approach to seal, via a dry-run or dev-inspect?)
// how would that verification look? Would we need a witness stuct `DeleteMessagePermission` to be part of groups AuthState?
// - edit message(s)
// verify permission to edit

/// Module: messaging
///
/// This module wraps the `permissions_group` library to provide messaging-specific
/// permission management. It defines messaging-specific permission types and delegates
/// to the underlying `PermissionsGroup` for core permission operations.
///
/// ## Permission Model
///
/// Base permissions (from groups library, granted to creator automatically):
/// - `PermissionsManager`: Can grant/revoke any permissions
/// - `MemberAdder`: Can add new members (with no permissions)
/// - `MemberRemover`: Can remove members
///
/// Messaging-specific permissions (defined in this module):
/// - `MessagingSender`: Can send messages
/// - `MessagingReader`: Can read/decrypt messages
/// - `MessagingDeleter`: Can delete messages
/// - `MessagingEditor`: Can edit messages
///
/// ## Security Model
///
/// - Adding a member (via `add_member`) only adds them to the roster with no permissions
/// - Granting permissions requires `PermissionsManager` permission
/// - This prevents privilege escalation where a `MemberAdder` could grant admin permissions
///
module messaging::messaging;

use groups::join_policy;
use groups::permissions_group::{Self, PermissionsGroup};
use messaging::encryption_history::{Self, EncryptionHistory, EncryptionKeyRotator};
use sui::dynamic_field;

// === Error Codes ===

const ENotPermitted: u64 = 0;
const EEncryptionNotEnabled: u64 = 1;

// === Permission Witnesses ===

// Separate permissions to read/send, in order to
// facilitate a ban/mute functionality by 3rdparty apps
// using the messaging as a dependency
/// Permission to send messages to the group
public struct MessagingSender() has drop;
/// Permission to read/decrypt messages from the group
public struct MessagingReader() has drop;
/// Permission to delete messages in the group
public struct MessagingDeleter() has drop;
/// Permission to edit messages in the group
public struct MessagingEditor() has drop;

// === Structs ===

/// A messaging group that wraps a PermissionsGroup with messaging-specific permissions.
public struct MessagingGroup has key {
    id: UID,
    permissions_group: PermissionsGroup,
    /// The address that created this group. Can be used as namespace for Seal encryption.
    creator: address,
}

// === Public Functions ===

/// Creates a new MessagingGroup with the caller as the creator.
/// The creator is automatically granted all permissions:
/// - From groups library: PermissionsManager, MemberAdder, MemberRemover
/// - Messaging-specific: MessagingSender, MessagingReader, MessagingDeleter, MessagingEditor
public fun new(ctx: &mut TxContext): MessagingGroup {
    let mut permissions_group = permissions_group::new(ctx);
    let group_creator = ctx.sender();

    // Grant messaging-specific permissions to creator
    permissions_group.grant_permission<MessagingSender>(group_creator, ctx);
    permissions_group.grant_permission<MessagingReader>(group_creator, ctx);
    permissions_group.grant_permission<MessagingDeleter>(group_creator, ctx);
    permissions_group.grant_permission<MessagingEditor>(group_creator, ctx);

    MessagingGroup {
        id: object::new(ctx),
        permissions_group,
        creator: group_creator,
    }
}

/// Creates a new MessagingGroup with encryption enabled.
/// The creator is automatically granted all permissions including EncryptionKeyRotator.
///
/// # Parameters
/// - `initial_encrypted_dek`: The initial encrypted DEK bytes (full EncryptedObject from Seal)
/// - `ctx`: Transaction context
///
/// # Returns
/// - A new `MessagingGroup` with encryption history attached
public fun new_with_encryption(
    initial_encrypted_dek: vector<u8>,
    ctx: &mut TxContext,
): MessagingGroup {
    let mut permissions_group = permissions_group::new(ctx);
    let group_creator = ctx.sender();

    // Grant messaging-specific permissions to creator
    permissions_group.grant_permission<MessagingSender>(group_creator, ctx);
    permissions_group.grant_permission<MessagingReader>(group_creator, ctx);
    permissions_group.grant_permission<MessagingDeleter>(group_creator, ctx);
    permissions_group.grant_permission<MessagingEditor>(group_creator, ctx);
    // Grant encryption key rotation permission to creator
    permissions_group.grant_permission<EncryptionKeyRotator>(group_creator, ctx);

    let mut group = MessagingGroup {
        id: object::new(ctx),
        permissions_group,
        creator: group_creator,
    };

    // Attach encryption history
    let history = encryption_history::new(initial_encrypted_dek, ctx);
    dynamic_field::add(&mut group.id, encryption_history::key(), history);

    group
}

/// Rotates the encryption key for this MessagingGroup.
/// Requires the caller to have EncryptionKeyRotator permission.
///
/// # Parameters
/// - `self`: Mutable reference to the MessagingGroup
/// - `new_encrypted_dek`: The new encrypted DEK bytes (full EncryptedObject from Seal)
/// - `ctx`: Transaction context
///
/// # Aborts
/// - If caller doesn't have EncryptionKeyRotator permission
/// - If encryption is not enabled for this group
public fun rotate_encryption_key(
    self: &mut MessagingGroup,
    new_encrypted_dek: vector<u8>,
    ctx: &TxContext,
) {
    assert!(self.has_permission<EncryptionKeyRotator>(ctx.sender()), ENotPermitted);
    assert!(dynamic_field::exists_(&self.id, encryption_history::key()), EEncryptionNotEnabled);

    let history: &mut EncryptionHistory = dynamic_field::borrow_mut(
        &mut self.id,
        encryption_history::key(),
    );
    history.rotate_key(new_encrypted_dek);
}

/// Returns the current encryption key version.
/// Returns 0 if encryption is not enabled.
public fun current_encryption_key_version(self: &MessagingGroup): u64 {
    if (!dynamic_field::exists_(&self.id, encryption_history::key())) {
        return 0
    };
    let history: &EncryptionHistory = dynamic_field::borrow(&self.id, encryption_history::key());
    history.current_key_version()
}

/// Returns the encrypted DEK for a specific version.
///
/// # Aborts
/// - If encryption is not enabled
/// - If the key version doesn't exist
public fun get_encrypted_key(self: &MessagingGroup, version: u64): vector<u8> {
    assert!(dynamic_field::exists_(&self.id, encryption_history::key()), EEncryptionNotEnabled);
    let history: &EncryptionHistory = dynamic_field::borrow(&self.id, encryption_history::key());
    history.get_encrypted_key(version)
}

/// Returns the encrypted DEK for the current (latest) version.
///
/// # Aborts
/// - If encryption is not enabled
public fun get_current_encrypted_key(self: &MessagingGroup): vector<u8> {
    assert!(dynamic_field::exists_(&self.id, encryption_history::key()), EEncryptionNotEnabled);
    let history: &EncryptionHistory = dynamic_field::borrow(&self.id, encryption_history::key());
    history.get_current_encrypted_key()
}

/// Checks if encryption is enabled for this MessagingGroup.
public fun has_encryption(self: &MessagingGroup): bool {
    dynamic_field::exists_(&self.id, encryption_history::key())
}

/// Adds a new member with no initial permissions.
/// Requires the caller to have MemberAdder permission.
/// Use `grant_permission` afterward to assign permissions to the new member.
///
/// # Aborts
/// - If caller does not have MemberAdder permission
/// - If new_member is already a member
public fun add_member(self: &mut MessagingGroup, new_member: address, ctx: &TxContext) {
    self.permissions_group.add_member(new_member, ctx);
}

/// Removes a member from the MessagingGroup.
/// Requires the caller to have MemberRemover permission.
///
/// # Aborts
/// - If caller does not have MemberRemover permission
/// - If member does not exist
/// - If removing the member would leave no PermissionsManager remaining
public fun remove_member(self: &mut MessagingGroup, member: address, ctx: &TxContext) {
    self.permissions_group.remove_member(member, ctx);
}

/// Allows the calling member to leave the MessagingGroup.
///
/// # Aborts
/// - If the caller is not a member
/// - If leaving would leave no PermissionsManager remaining
public fun leave(self: &mut MessagingGroup, ctx: &TxContext) {
    self.permissions_group.leave(ctx);
}

/// Grants a permission to an existing member.
/// Requires the caller to have PermissionsManager permission.
///
/// # Type Parameters
/// - `Permission`: The permission type to grant
///
/// # Aborts
/// - If caller does not have PermissionsManager permission
/// - If member does not exist
public fun grant_permission<Permission: drop>(
    self: &mut MessagingGroup,
    member: address,
    ctx: &TxContext,
) {
    self.permissions_group.grant_permission<Permission>(member, ctx);
}

/// Revokes a permission from a member.
/// Requires the caller to have PermissionsManager permission.
///
/// # Type Parameters
/// - `Permission`: The permission type to revoke
///
/// # Aborts
/// - If caller does not have PermissionsManager permission
/// - If member does not exist
/// - If revoking PermissionsManager would leave none remaining
public fun revoke_permission<Permission: drop>(
    self: &mut MessagingGroup,
    member: address,
    ctx: &TxContext,
) {
    self.permissions_group.revoke_permission<Permission>(member, ctx);
}

/// Checks if the caller has the specified permission.
public fun is_authorized<Permission: drop>(self: &MessagingGroup, ctx: &TxContext): bool {
    self.permissions_group.has_permission<Permission>(ctx.sender())
}

/// Checks if an address has the specified permission.
public fun has_permission<Permission: drop>(self: &MessagingGroup, member: address): bool {
    self.permissions_group.has_permission<Permission>(member)
}

/// Checks if the given address is a member of the MessagingGroup.
public fun is_member(self: &MessagingGroup, member: address): bool {
    self.permissions_group.is_member(member)
}

/// Returns the creator address of this MessagingGroup.
/// Can be used as namespace for Seal encryption identity bytes.
public fun creator(self: &MessagingGroup): address {
    self.creator
}

// === JoinPolicy Integration ===

/// Adds a new member using a JoinApproval from the join_policy module.
/// This is the safe way to add members via JoinPolicy - the approval proves
/// that all policy rules were satisfied.
///
/// # Type Parameters
/// - `T`: The policy's witness type
///
/// # Parameters
/// - `self`: Mutable reference to the `MessagingGroup` state.
/// - `approval`: The JoinApproval proving the policy was satisfied (consumed).
///
/// # Aborts
/// - If the member is already in the group.
public fun add_member_with_approval<T>(
    self: &mut MessagingGroup,
    approval: join_policy::JoinApproval<T>,
) {
    self.permissions_group.add_member_with_approval(approval);
}
