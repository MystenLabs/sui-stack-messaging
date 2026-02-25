/// Module: suins_manager
///
/// Actor object that allows authorized callers to set/unset SuiNS reverse
/// lookups on `PermissionedGroup<T>` objects.
///
/// `SuinsManager` is a derived singleton object from `MessagingNamespace`.
/// It is granted `ObjectAdmin` on every group created via `messaging::create_group`,
/// and exposes `set_reverse_lookup` / `unset_reverse_lookup` functions that call
/// `object_uid_mut` on the group to obtain a `&mut UID` for the SuiNS controller.
///
/// This module does NOT import `messaging.move` to avoid a circular dependency.
/// The generic functions are instantiated with the concrete `Messaging` type
/// at the call site in `messaging.move`.
///
/// All public entry points are in the `messaging` module:
/// - `messaging::set_suins_reverse_lookup`
/// - `messaging::unset_suins_reverse_lookup`
module messaging::suins_manager;

use permissioned_groups::permissioned_group::PermissionedGroup;
use std::string::String;
use sui::derived_object;
use suins::controller;
use suins::suins::SuiNS;

// === Derivation Key ===

/// Fixed derivation key for the singleton `SuinsManager` derived from `MessagingNamespace`.
const SUINS_MANAGER_DERIVATION_KEY: vector<u8> = b"suins_manager";

// === Structs ===

/// Actor object that holds `ObjectAdmin` on all messaging groups.
/// The `id` field is intentionally private — no UID getter is exposed.
/// All SuiNS operations go through the package-internal functions.
public struct SuinsManager has key {
    id: UID,
}

// === Package Functions ===

/// Creates a new `SuinsManager` derived from the namespace UID.
/// Called once during `messaging::init`.
///
/// # Parameters
/// - `namespace_uid`: Mutable reference to the `MessagingNamespace` UID
///
/// # Returns
/// A new `SuinsManager` object with a deterministic address.
public(package) fun new(namespace_uid: &mut UID): SuinsManager {
    SuinsManager {
        id: derived_object::claim(namespace_uid, SUINS_MANAGER_DERIVATION_KEY.to_string()),
    }
}

/// Shares the `SuinsManager` object on-chain.
/// Called once during `messaging::init` after creating the object.
public(package) fun share(self: SuinsManager) {
    transfer::share_object(self);
}

/// Returns the fixed derivation key string.
/// Used by `messaging::create_group` to compute the `SuinsManager`'s address via
/// `derived_object::derive_address` without holding the object.
///
/// # Returns
/// The string key used for address derivation.
public(package) fun derivation_key(): String {
    SUINS_MANAGER_DERIVATION_KEY.to_string()
}

/// Sets a SuiNS reverse lookup on a group.
/// The `SuinsManager` must have `ObjectAdmin` on the group (granted at creation time).
///
/// Generic over `T: drop` so this module does not need to import `messaging.move`.
/// Instantiated as `set_reverse_lookup<Messaging>` at the call site in `messaging.move`.
///
/// # Parameters
/// - `self`: Reference to the `SuinsManager` actor
/// - `group`: Mutable reference to the group
/// - `suins`: Mutable reference to the SuiNS shared object
/// - `domain_name`: The domain name to set as reverse lookup
///
/// # Aborts
/// - `ENotPermitted`: if this actor doesn't have `ObjectAdmin` on the group
public(package) fun set_reverse_lookup<T: drop>(
    self: &SuinsManager,
    group: &mut PermissionedGroup<T>,
    suins: &mut SuiNS,
    domain_name: String,
) {
    let uid = group.object_uid_mut<T>(&self.id);
    controller::set_object_reverse_lookup(suins, uid, domain_name);
}

/// Unsets a SuiNS reverse lookup on a group.
/// The `SuinsManager` must have `ObjectAdmin` on the group (granted at creation time).
///
/// Generic over `T: drop` so this module does not need to import `messaging.move`.
/// Instantiated as `unset_reverse_lookup<Messaging>` at the call site in `messaging.move`.
///
/// # Parameters
/// - `self`: Reference to the `SuinsManager` actor
/// - `group`: Mutable reference to the group
/// - `suins`: Mutable reference to the SuiNS shared object
///
/// # Aborts
/// - `ENotPermitted`: if this actor doesn't have `ObjectAdmin` on the group
public(package) fun unset_reverse_lookup<T: drop>(
    self: &SuinsManager,
    group: &mut PermissionedGroup<T>,
    suins: &mut SuiNS,
) {
    let uid = group.object_uid_mut<T>(&self.id);
    controller::unset_object_reverse_lookup(suins, uid);
}