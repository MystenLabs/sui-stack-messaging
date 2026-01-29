/// Module: seal_policies
///
/// Default `seal_approve` functions for Seal encryption access control.
/// Called by Seal key servers (via dry-run) to authorize decryption.
///
/// ## Identity Bytes Format
///
/// Identity bytes: `[encryptor_address (32 bytes)][nonce (32 bytes)]`
/// Each key version has its own identity bytes stored in EncryptionHistory.
/// The encryptor is the address that encrypted the DEK (creator or key rotator).
///
/// ## Custom Policies
///
/// Apps can implement custom `seal_approve` with different logic:
/// - Subscription-based, time-limited, NFT-gated access, etc.
/// - Must be in the same package used during `seal.encrypt`.
///
module messaging::seal_policies;

use messaging::encryption_history::EncryptionHistory;
use messaging::messaging::{MessagingReader, Messaging};
use permissioned_groups::permissioned_group::PermissionedGroup;

// === Error Codes ===

const EInvalidIdentityBytes: u64 = 0;
const ENotPermitted: u64 = 1;
const EGroupMismatch: u64 = 2;

// === Private Functions ===

/// Validates identity bytes and MessagingReader permission for a specific key version.
fun approve_reader_for_version(
    id: &vector<u8>,
    key_version: u64,
    encryption_history: &EncryptionHistory,
    group: &PermissionedGroup<Messaging>,
    ctx: &TxContext,
) {
    // Validate encryption history belongs to this group
    assert!(encryption_history.group_id() == object::id(group), EGroupMismatch);

    // Validate identity bytes match stored identity for this key version
    let stored_identity = encryption_history.identity_bytes_for_version(key_version);
    assert!(*id == stored_identity, EInvalidIdentityBytes);

    // Check caller has MessagingReader permission
    assert!(group.has_permission<Messaging, MessagingReader>(ctx.sender()), ENotPermitted);
}

// === Entry Functions ===

/// Seal approve for the current (latest) key version.
///
/// Validates that the identity bytes match the stored identity bytes for the
/// current key version, then checks the caller has `MessagingReader` permission.
///
/// # Parameters
/// - `id`: Seal identity bytes `[encryptor_address (32 bytes)][nonce (32 bytes)]`
/// - `encryption_history`: Reference to the group's EncryptionHistory
/// - `group`: Reference to the PermissionedGroup<Messaging>
/// - `ctx`: Transaction context
///
/// # Aborts
/// - `EGroupMismatch`: if encryption_history doesn't belong to this group
/// - `EInvalidIdentityBytes`: if `id` doesn't match the current key version's identity bytes
/// - `ENotPermitted`: if caller doesn't have `MessagingReader` permission
entry fun seal_approve_reader(
    id: vector<u8>,
    encryption_history: &EncryptionHistory,
    group: &PermissionedGroup<Messaging>,
    ctx: &TxContext,
) {
    let current_version = encryption_history.current_key_version();
    approve_reader_for_version(&id, current_version, encryption_history, group, ctx);
}

/// Seal approve for a specific key version.
///
/// Use this to decrypt messages that were encrypted with an older key version
/// after key rotation.
///
/// # Parameters
/// - `id`: Seal identity bytes `[encryptor_address (32 bytes)][nonce (32 bytes)]`
/// - `key_version`: The encryption key version to validate against
/// - `encryption_history`: Reference to the group's EncryptionHistory
/// - `group`: Reference to the PermissionedGroup<Messaging>
/// - `ctx`: Transaction context
///
/// # Aborts
/// - `EGroupMismatch`: if encryption_history doesn't belong to this group
/// - `EInvalidIdentityBytes`: if `id` doesn't match the stored identity bytes for key_version
/// - `ENotPermitted`: if caller doesn't have `MessagingReader` permission
entry fun seal_approve_reader_for_version(
    id: vector<u8>,
    key_version: u64,
    encryption_history: &EncryptionHistory,
    group: &PermissionedGroup<Messaging>,
    ctx: &TxContext,
) {
    approve_reader_for_version(&id, key_version, encryption_history, group, ctx);
}
