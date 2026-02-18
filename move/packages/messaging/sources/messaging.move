/// Module: messaging
///
/// Public-facing module for the messaging package. All external interactions
/// should go through this module.
///
/// Wraps `permissions_group` to provide messaging-specific permission management
/// and `encryption_history` for key rotation.
///
/// ## Permissions
///
/// From groups (auto-granted to creator):
/// - `PermissionsAdmin`: Manages core permissions (from permissioned_groups package)
/// - `ExtensionPermissionsAdmin`: Manages extension permissions (from other packages)
///
/// Messaging-specific:
/// - `MessagingSender`: Send messages
/// - `MessagingReader`: Read/decrypt messages
/// - `MessagingEditor`: Edit messages
/// - `MessagingDeleter`: Delete messages
/// - `EncryptionKeyRotator`: Rotate encryption keys
/// - `SuiNsAdmin`: Manage SuiNS reverse lookups on the group
/// - `MetadataAdmin`: Edit group metadata (name, data)
///
/// ## Security
///
/// - Membership is defined by having at least one permission
/// - Granting a permission implicitly adds the member if they don't exist
/// - Revoking the last permission automatically removes the member
///
module messaging::messaging;

use messaging::encryption_history::{Self, EncryptionHistory, EncryptionKeyRotator};
use messaging::group_leaver::{Self, GroupLeaver};
use messaging::group_manager::{Self, GroupManager};
use messaging::metadata::{Self};
use messaging::version::Version;
use permissioned_groups::permissioned_group::{
    Self, PermissionedGroup, PermissionsAdmin, ObjectAdmin,
};
use std::string::String;
use sui::package;
use sui::vec_set::{Self, VecSet};
use suins::suins::SuiNS;

// === Error Codes ===

/// Caller lacks the required permission for the operation.
const ENotPermitted: u64 = 0;
/// Operation is not yet implemented.
const ENotImplemented: u64 = 1;

// === Witnesses ===

/// One-Time Witness for claiming Publisher.
public struct MESSAGING() has drop;

/// Package witness for `PermissionedGroup<Messaging>`.
public struct Messaging() has drop;

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

/// Permission to manage SuiNS reverse lookups on the group.
public struct SuiNsAdmin() has drop;

/// Permission to edit group metadata (name, data).
public struct MetadataAdmin() has drop;

// === Structs ===

/// Shared object used as namespace for deriving group and encryption history addresses.
/// One per package deployment.
public struct MessagingNamespace has key {
    id: UID,
}

fun init(otw: MESSAGING, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);

    let mut namespace = MessagingNamespace {
        id: object::new(ctx),
    };

    let group_leaver = group_leaver::new(&mut namespace.id);
    let group_manager = group_manager::new(&mut namespace.id);
    transfer::share_object(namespace);
    group_leaver::share(group_leaver);
    group_manager::share(group_manager);
}

// === Public Functions ===

/// Creates a new messaging group with encryption.
/// The transaction sender (`ctx.sender()`) automatically becomes the creator with all permissions.
///
/// # Parameters
/// - `version`: Reference to the Version shared object
/// - `namespace`: Mutable reference to the MessagingNamespace
/// - `group_manager`: Reference to the shared GroupManager actor
/// - `name`: Human-readable group name
/// - `uuid`: Client-provided UUID for deterministic address derivation
/// - `initial_encrypted_dek`: Initial Seal-encrypted DEK bytes
/// - `initial_members`: Addresses to grant `MessagingReader` permission (should not include
/// creator)
/// - `ctx`: Transaction context
///
/// # Returns
/// Tuple of `(PermissionedGroup<Messaging>, EncryptionHistory)`.
///
/// # Note
/// If `initial_members` contains the creator's address, it is silently skipped (no abort).
/// This handles the common case where the creator might be mistakenly included in the initial
/// members list.
///
/// # Aborts
/// - `EInvalidVersion` (from `version`): if package version doesn't match
/// - If the UUID has already been used (duplicate derivation)
public fun create_group(
    version: &Version,
    namespace: &mut MessagingNamespace,
    group_manager: &GroupManager,
    name: String,
    uuid: String,
    initial_encrypted_dek: vector<u8>,
    initial_members: VecSet<address>,
    ctx: &mut TxContext,
): (PermissionedGroup<Messaging>, EncryptionHistory) {
    version.validate_version();
    let mut group: PermissionedGroup<Messaging> = permissioned_group::new_derived<
        Messaging,
        encryption_history::PermissionedGroupTag,
    >(
        Messaging(),
        &mut namespace.id,
        encryption_history::permissions_group_tag(uuid),
        ctx,
    );

    let creator = ctx.sender();
    grant_all_messaging_permissions(&mut group, creator, ctx);

    // Grant PermissionsAdmin to the GroupLeaver actor so it can remove members on behalf of callers.
    // The address is derived deterministically from the namespace — no need to pass the object.
    let group_leaver_address = sui::derived_object::derive_address(
        object::id(namespace),
        group_leaver::derivation_key(),
    );
    group.grant_permission<Messaging, PermissionsAdmin>(group_leaver_address, ctx);

    // Grant ObjectAdmin to the GroupManager actor so it can access the group UID
    // for SuiNS reverse lookups and metadata management.
    group.grant_permission<Messaging, ObjectAdmin>(
        object::id(group_manager).to_address(),
        ctx,
    );

    // Attach Metadata via GroupManager
    let m = metadata::new(name, uuid, creator);
    group_manager::attach_metadata<Messaging>(group_manager, &mut group, m);

    // Grant MessagingReader permission to initial members (skip creator)
    initial_members.into_keys().do!(|member| {
        if (member != creator) {
            group.grant_permission<Messaging, MessagingReader>(member, ctx);
        };
    });

    let encryption_history = encryption_history::new(
        &mut namespace.id,
        uuid,
        object::id(&group),
        initial_encrypted_dek,
        ctx,
    );

    (group, encryption_history)
}

/// Creates a new messaging group and shares both objects.
///
/// # Parameters
/// - `version`: Reference to the Version shared object
/// - `namespace`: Mutable reference to the MessagingNamespace
/// - `group_manager`: Reference to the shared GroupManager actor
/// - `name`: Human-readable group name
/// - `uuid`: Client-provided UUID for deterministic address derivation
/// - `initial_encrypted_dek`: Initial Seal-encrypted DEK bytes
/// - `initial_members`: Set of addresses to grant `MessagingReader` permission
/// - `ctx`: Transaction context
///
/// # Note
/// See `create_group` for details on creator permissions and initial member handling.
#[allow(lint(share_owned))]
entry fun create_and_share_group(
    version: &Version,
    namespace: &mut MessagingNamespace,
    group_manager: &GroupManager,
    name: String,
    uuid: String,
    initial_encrypted_dek: vector<u8>,
    initial_members: vector<address>,
    ctx: &mut TxContext,
) {
    let (group, encryption_history) = create_group(
        version,
        namespace,
        group_manager,
        name,
        uuid,
        initial_encrypted_dek,
        vec_set::from_keys(initial_members),
        ctx,
    );
    transfer::public_share_object(group);
    transfer::public_share_object(encryption_history);
}

/// Rotates the encryption key for a group.
///
/// # Parameters
/// - `encryption_history`: Mutable reference to the group's EncryptionHistory
/// - `group`: Reference to the PermissionedGroup<Messaging>
/// - `new_encrypted_dek`: New Seal-encrypted DEK bytes
/// - `ctx`: Transaction context
///
/// # Aborts
/// - `EInvalidVersion` (from `version`): if package version doesn't match
/// - `ENotPermitted`: if caller doesn't have `EncryptionKeyRotator` permission
public fun rotate_encryption_key(
    version: &Version,
    encryption_history: &mut EncryptionHistory,
    group: &PermissionedGroup<Messaging>,
    new_encrypted_dek: vector<u8>,
    ctx: &TxContext,
) {
    version.validate_version();
    assert!(group.has_permission<Messaging, EncryptionKeyRotator>(ctx.sender()), ENotPermitted);
    encryption_history.rotate_key(new_encrypted_dek);
}

/// Removes the caller from a messaging group.
/// The `GroupLeaver` actor holds `PermissionsAdmin` on all groups and calls
/// `object_remove_member` on behalf of the caller.
///
/// # Parameters
/// - `group_leaver`: Reference to the shared `GroupLeaver` object
/// - `group`: Mutable reference to the `PermissionedGroup<Messaging>`
/// - `ctx`: Transaction context
///
/// # Aborts
/// - `EMemberNotFound` (from `permissioned_group`): if the caller is not a member
/// - `ELastPermissionsAdmin` (from `permissioned_group`): if the caller is the last
///   `PermissionsAdmin` holder (including actor objects)
///
/// NOTE: Because `GroupLeaver` itself holds `PermissionsAdmin` on every group, a human
/// admin can always leave — leaving `GroupLeaver` as the sole remaining admin. A group in
/// that state has no human admins. To promote a new human admin from that state, a
/// dedicated actor-object wrapper over `object_grant_permission` would be needed.
public fun leave(
    group_leaver: &GroupLeaver,
    group: &mut PermissionedGroup<Messaging>,
    ctx: &TxContext,
) {
    group_leaver::leave<Messaging>(group_leaver, group, ctx);
}

// === SuiNS Functions ===

/// Sets a SuiNS reverse lookup on a messaging group.
/// The caller must have `SuiNsAdmin` permission on the group.
/// The `GroupManager` actor internally holds `ObjectAdmin` to access the group UID.
///
/// # Parameters
/// - `group_manager`: Reference to the shared `GroupManager` actor
/// - `group`: Mutable reference to the `PermissionedGroup<Messaging>`
/// - `suins`: Mutable reference to the SuiNS shared object
/// - `domain_name`: The domain name to set as reverse lookup
/// - `ctx`: Transaction context
///
/// # Aborts
/// - `ENotPermitted`: if caller doesn't have `SuiNsAdmin`
public fun set_suins_reverse_lookup(
    group_manager: &GroupManager,
    group: &mut PermissionedGroup<Messaging>,
    suins: &mut SuiNS,
    domain_name: String,
    ctx: &TxContext,
) {
    assert!(
        group.has_permission<Messaging, SuiNsAdmin>(ctx.sender()),
        ENotPermitted,
    );
    group_manager::set_reverse_lookup<Messaging>(group_manager, group, suins, domain_name);
}

/// Unsets a SuiNS reverse lookup on a messaging group.
/// The caller must have `SuiNsAdmin` permission on the group.
/// The `GroupManager` actor internally holds `ObjectAdmin` to access the group UID.
///
/// # Parameters
/// - `group_manager`: Reference to the shared `GroupManager` actor
/// - `group`: Mutable reference to the `PermissionedGroup<Messaging>`
/// - `suins`: Mutable reference to the SuiNS shared object
/// - `ctx`: Transaction context
///
/// # Aborts
/// - `ENotPermitted`: if caller doesn't have `SuiNsAdmin`
public fun unset_suins_reverse_lookup(
    group_manager: &GroupManager,
    group: &mut PermissionedGroup<Messaging>,
    suins: &mut SuiNS,
    ctx: &TxContext,
) {
    assert!(
        group.has_permission<Messaging, SuiNsAdmin>(ctx.sender()),
        ENotPermitted,
    );
    group_manager::unset_reverse_lookup<Messaging>(group_manager, group, suins);
}

// === Metadata Functions ===

/// Sets the group name.
/// Caller must have `MetadataAdmin` permission.
///
/// # Aborts
/// - `ENotPermitted`: if caller doesn't have `MetadataAdmin`
/// - `ENameTooLong` (from `metadata`): if name exceeds limit
public fun set_group_name(
    group_manager: &GroupManager,
    group: &mut PermissionedGroup<Messaging>,
    name: String,
    ctx: &TxContext,
) {
    assert!(group.has_permission<Messaging, MetadataAdmin>(ctx.sender()), ENotPermitted);
    let m = group_manager::borrow_metadata_mut<Messaging>(group_manager, group);
    m.set_name(name);
}

/// Inserts a key-value pair into the group's metadata data map.
/// Caller must have `MetadataAdmin` permission.
///
/// # Aborts
/// - `ENotPermitted`: if caller doesn't have `MetadataAdmin`
/// - `EDataKeyTooLong` (from `metadata`): if key exceeds limit
/// - `EDataValueTooLong` (from `metadata`): if value exceeds limit
public fun insert_group_data(
    group_manager: &GroupManager,
    group: &mut PermissionedGroup<Messaging>,
    key: String,
    value: String,
    ctx: &TxContext,
) {
    assert!(group.has_permission<Messaging, MetadataAdmin>(ctx.sender()), ENotPermitted);
    let m = group_manager::borrow_metadata_mut<Messaging>(group_manager, group);
    m.insert_data(key, value);
}

/// Removes a key-value pair from the group's metadata data map.
/// Caller must have `MetadataAdmin` permission.
///
/// # Returns
/// The removed (key, value) tuple.
///
/// # Aborts
/// - `ENotPermitted`: if caller doesn't have `MetadataAdmin`
public fun remove_group_data(
    group_manager: &GroupManager,
    group: &mut PermissionedGroup<Messaging>,
    key: &String,
    ctx: &TxContext,
): (String, String) {
    assert!(group.has_permission<Messaging, MetadataAdmin>(ctx.sender()), ENotPermitted);
    let m = group_manager::borrow_metadata_mut<Messaging>(group_manager, group);
    m.remove_data(key)
}

// === Archive (Stub) ===

/// Archives a messaging group.
/// TODO: Full implementation deferred — open design questions about:
/// - Should archived groups still support Seal decryption?
/// - Destroy + ArchivedGroup vs freeze-in-place with marker?
/// - Dynamic field cleanup strategy
entry fun archive_group(
    _version: &Version,
    _group_manager: &GroupManager,
    _group: PermissionedGroup<Messaging>,
    _ctx: &mut TxContext,
) {
    abort ENotImplemented
}

/// Grants all messaging permissions to a member.
/// Includes: `MessagingSender`, `MessagingReader`, `MessagingEditor`,
/// `MessagingDeleter`, `EncryptionKeyRotator`, `SuiNsAdmin`, `MetadataAdmin`.
fun grant_all_messaging_permissions(
    group: &mut PermissionedGroup<Messaging>,
    member: address,
    ctx: &TxContext,
) {
    group.grant_permission<Messaging, MessagingSender>(member, ctx);
    group.grant_permission<Messaging, MessagingReader>(member, ctx);
    group.grant_permission<Messaging, MessagingEditor>(member, ctx);
    group.grant_permission<Messaging, MessagingDeleter>(member, ctx);
    group.grant_permission<Messaging, EncryptionKeyRotator>(member, ctx);
    group.grant_permission<Messaging, SuiNsAdmin>(member, ctx);
    group.grant_permission<Messaging, MetadataAdmin>(member, ctx);
}

// === Test Helpers ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(MESSAGING(), ctx);
}

#[test_only]
public fun get_otw_for_testing(): MESSAGING {
    MESSAGING()
}
