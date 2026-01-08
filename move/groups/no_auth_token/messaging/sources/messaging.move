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

use groups::permissions_group::{Self, PermissionsGroup};
use messaging::encryption_history::{Self, EncryptionHistory, EncryptionKeyRotator};
use sui::dynamic_field;

// === Error Codes ===

const ENotPermitted: u64 = 0;
const EEncryptionNotEnabled: u64 = 1;

// === Witnesses ===

/// Package witness
/// Meant to be used with permission groups:
/// `permissions_group::PermissionsGroup<MessagingApp>`
public struct MessagingApp() has drop;

// === Permission Witnesses ===

/// Permission to send messages to the group.
/// Separate from `MessagingReader` to enable mute functionality.
public struct MessagingSender() has drop;

/// Permission to read/decrypt messages from the group.
/// Separate from `MessagingSender` to enable read-only or write-only access.
public struct MessagingReader() has drop;

/// Permission to delete messages in the group.
public struct MessagingDeleter() has drop;

/// Permission to edit messages in the group.
public struct MessagingEditor() has drop;

// === Structs ===

// === Public Functions ===

/// Creates a new MessagingGroup with the caller as the creator.
///
/// The creator is automatically granted all permissions:
/// - From groups library: `PermissionsManager`, `MemberAdder`, `MemberRemover`
/// - Messaging-specific: `MessagingSender`, `MessagingReader`, `MessagingDeleter`,
/// `MessagingEditor`
///
/// # Parameters
/// - `ctx`: Transaction context
///
/// # Returns
/// A new `MessagingGroup` with the caller as creator and all permissions granted.
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
///
/// The creator is automatically granted all permissions including `EncryptionKeyRotator`.
///
/// # Parameters
/// - `initial_encrypted_dek`: The initial encrypted DEK bytes (full EncryptedObject from Seal)
/// - `ctx`: Transaction context
///
/// # Returns
/// A new `MessagingGroup` with encryption history attached.
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
///
/// # Parameters
/// - `self`: Mutable reference to the MessagingGroup
/// - `new_encrypted_dek`: The new encrypted DEK bytes (full EncryptedObject from Seal)
/// - `ctx`: Transaction context
///
/// # Aborts
/// - If caller doesn't have `EncryptionKeyRotator` permission.
/// - If encryption is not enabled for this group.
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

/// Returns the current encryption key version (0-indexed).
///
/// # Returns
/// The current key version, or 0 if encryption is not enabled.
public fun current_encryption_key_version(self: &MessagingGroup): u64 {
    if (!dynamic_field::exists_(&self.id, encryption_history::key())) {
        return 0
    };
    let history: &EncryptionHistory = dynamic_field::borrow(&self.id, encryption_history::key());
    history.current_key_version()
}

/// Returns the encrypted DEK for a specific version.
///
/// # Parameters
/// - `self`: Reference to the MessagingGroup
/// - `version`: The key version to retrieve (0-indexed)
///
/// # Returns
/// The encrypted DEK bytes for the specified version.
///
/// # Aborts
/// - If encryption is not enabled.
/// - If the key version doesn't exist.
public fun get_encrypted_key(self: &MessagingGroup, version: u64): vector<u8> {
    assert!(dynamic_field::exists_(&self.id, encryption_history::key()), EEncryptionNotEnabled);
    let history: &EncryptionHistory = dynamic_field::borrow(&self.id, encryption_history::key());
    history.get_encrypted_key(version)
}

/// Returns the encrypted DEK for the current (latest) version.
///
/// # Returns
/// The encrypted DEK bytes for the current version.
///
/// # Aborts
/// - If encryption is not enabled.
public fun get_current_encrypted_key(self: &MessagingGroup): vector<u8> {
    assert!(dynamic_field::exists_(&self.id, encryption_history::key()), EEncryptionNotEnabled);
    let history: &EncryptionHistory = dynamic_field::borrow(&self.id, encryption_history::key());
    history.get_current_encrypted_key()
}

/// Checks if encryption is enabled for this MessagingGroup.
///
/// # Returns
/// `true` if encryption is enabled, `false` otherwise.
public fun has_encryption(self: &MessagingGroup): bool {
    dynamic_field::exists_(&self.id, encryption_history::key())
}

/// Adds a new member with no initial permissions.
///
/// Use `grant_permission` afterward to assign permissions to the new member.
///
/// # Parameters
/// - `self`: Mutable reference to the MessagingGroup
/// - `new_member`: Address of the new member to add
/// - `ctx`: Transaction context
///
/// # Aborts
/// - If caller does not have `MemberAdder` permission.
/// - If `new_member` is already a member.
public fun add_member(self: &mut MessagingGroup, new_member: address, ctx: &TxContext) {
    self.permissions_group.add_member(new_member, ctx);
}

/// Removes a member from the MessagingGroup.
///
/// # Parameters
/// - `self`: Mutable reference to the MessagingGroup
/// - `member`: Address of the member to remove
/// - `ctx`: Transaction context
///
/// # Aborts
/// - If caller does not have `MemberRemover` permission.
/// - If member does not exist.
/// - If removing the member would leave no `PermissionsManager` remaining.
public fun remove_member(self: &mut MessagingGroup, member: address, ctx: &TxContext) {
    self.permissions_group.remove_member(member, ctx);
}

/// Allows the calling member to leave the MessagingGroup.
///
/// # Parameters
/// - `self`: Mutable reference to the MessagingGroup
/// - `ctx`: Transaction context
///
/// # Aborts
/// - If the caller is not a member.
/// - If leaving would leave no `PermissionsManager` remaining.
public fun leave(self: &mut MessagingGroup, ctx: &TxContext) {
    self.permissions_group.leave(ctx);
}

/// Grants a permission to an existing member.
///
/// # Type Parameters
/// - `Permission`: The permission type to grant
///
/// # Parameters
/// - `self`: Mutable reference to the MessagingGroup
/// - `member`: Address of the member to grant permission to
/// - `ctx`: Transaction context
///
/// # Aborts
/// - If caller does not have `PermissionsManager` permission.
/// - If member does not exist.
public fun grant_permission<Permission: drop>(
    self: &mut MessagingGroup,
    member: address,
    ctx: &TxContext,
) {
    self.permissions_group.grant_permission<Permission>(member, ctx);
}

/// Revokes a permission from a member.
///
/// # Type Parameters
/// - `Permission`: The permission type to revoke
///
/// # Parameters
/// - `self`: Mutable reference to the MessagingGroup
/// - `member`: Address of the member to revoke permission from
/// - `ctx`: Transaction context
///
/// # Aborts
/// - If caller does not have `PermissionsManager` permission.
/// - If member does not exist.
/// - If revoking `PermissionsManager` would leave none remaining.
public fun revoke_permission<Permission: drop>(
    self: &mut MessagingGroup,
    member: address,
    ctx: &TxContext,
) {
    self.permissions_group.revoke_permission<Permission>(member, ctx);
}

/// Checks if the caller has the specified permission.
///
/// # Type Parameters
/// - `Permission`: The permission type to check for
///
/// # Returns
/// `true` if the caller has the permission, `false` otherwise.
public fun is_authorized<Permission: drop>(self: &MessagingGroup, ctx: &TxContext): bool {
    self.permissions_group.has_permission<Permission>(ctx.sender())
}

/// Checks if an address has the specified permission.
///
/// # Type Parameters
/// - `Permission`: The permission type to check for
///
/// # Parameters
/// - `self`: Reference to the MessagingGroup
/// - `member`: Address to check for the permission
///
/// # Returns
/// `true` if the address has the permission, `false` otherwise.
public fun has_permission<Permission: drop>(self: &MessagingGroup, member: address): bool {
    self.permissions_group.has_permission<Permission>(member)
}

/// Checks if the given address is a member of the MessagingGroup.
///
/// # Parameters
/// - `self`: Reference to the MessagingGroup
/// - `member`: Address to check for membership
///
/// # Returns
/// `true` if the address is a member, `false` otherwise.
public fun is_member(self: &MessagingGroup, member: address): bool {
    self.permissions_group.is_member(member)
}

/// Returns the creator address of this MessagingGroup.
///
/// Can be used as the namespace prefix for Seal encryption identity bytes.
///
/// # Returns
/// The address of the group creator.
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
