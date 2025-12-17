/// Module: permissions_group
///
/// TODO1: It might make more sense to just have PermissionsGranter and PermissionsRevoker
/// We DO want to have separate permissions for adding/removing because removing a member is
/// a more privileged/dangerous operation than adding a member.
/// So, I propose to either have PermissionsManager + separate MemberAdder/MemberRemover
/// Or just PermissionsGranter + PermissionsRevoker
/// For now, we will keep PermissionsManager + MemberAdder/MemberRemover
///
/// TODO2: we currently check and ensure there is always at least one PermissionsManager,
/// Should we also check for at least one MemberAdder and one MemberRemover?
/// I guess this is where it starts getting ugly having 3 separate permissions instead of just
/// granter/revoker. (of course a single PermissionsManager would be even simpler, but as mentioned
/// above
/// less flexible. And since we plan on offering this as a library, flexibility is important.)
/// One other option is to not expose add_member/remove_member functions at all, and leave the
/// implementation
/// and gating of those functions to the user of the library.
///
/// TODO3: Should we keep the assertions in the functions, or leave the responsibility to the
/// developer using
/// this library? I believe it would be ok, if we manage to implement the typed_witness
/// Auth<Permission> token
/// pattern. But, until then, I believe we should handle the assertions in this library.
///
module groups::permissions_group;

use groups::join_policy;
use std::type_name::{Self, TypeName};
use sui::table::{Self, Table};
use sui::vec_set::{Self, VecSet};

// === Error Codes ===

const ENotPermitted: u64 = 0;
const EMemberNotFound: u64 = 1;
// Error code for attempting to revoke the last PermissionsManager permission
const ELastPermissionsManager: u64 = 2;

// === Witnesses ===

// TODO4: Would it make sense to make those generic <phantom T> ?

/// Witness type representing the permission to grant or revoke permissions.
public struct PermissionsManager() has drop;
/// Witness type representing the permission to add members.
public struct MemberAdder() has drop;
/// Witness type representing the permission to remove members.
public struct MemberRemover() has drop;

// === Structs ===

// TODO5: does this need to be <phantom T> ?
/// Authorization state mapping addresses to their granted permissions
/// represented as TypeNames.
public struct PermissionsGroup has store {
    permissions: Table<address, VecSet<TypeName>>,
    managers_count: u64,
}

// === Public Functions ===

// TODO6: does this need to be generic <T> ?
/// Creates a new PermissionsGroup with the transaction sender as the initial
/// manager, adder, and remover.
///
/// # Parameters
/// - `ctx`: Mutable transaction context for the table creation.
///
/// # Returns
/// - A new `PermissionsGroup` object with the sender having all managing permissions.
public fun new(ctx: &mut TxContext): PermissionsGroup {
    let mut creator_permissions_set = vec_set::empty<TypeName>();
    creator_permissions_set.insert(type_name::with_defining_ids<PermissionsManager>());
    creator_permissions_set.insert(type_name::with_defining_ids<MemberAdder>());
    creator_permissions_set.insert(type_name::with_defining_ids<MemberRemover>());

    let mut permissions_table = table::new<address, VecSet<TypeName>>(ctx);
    permissions_table.add(ctx.sender(), creator_permissions_set);

    PermissionsGroup {
        permissions: permissions_table,
        managers_count: 1,
    }
}

/// Adds a new member with no initial permissions.
/// The caller must have MemberAdder permission.
/// After adding, use `grant_permission` to assign permissions to the new member.
///
/// # Parameters
/// - `self`: Mutable reference to the `PermissionsGroup` state.
/// - `new_member`: Address of the new member to be added.
/// - `ctx`: Transaction context for permission checks.
///
/// # Aborts
/// - If caller does not have MemberAdder permission.
/// - If new_member is already a member.
public fun add_member(self: &mut PermissionsGroup, new_member: address, ctx: &TxContext) {
    // assert caller has MemberAdder permission
    assert!(self.has_permission<MemberAdder>(ctx.sender()), ENotPermitted);
    // assert new_member is not already present
    assert!(!self.is_member(new_member), EMemberNotFound);
    // Add member with empty permissions set
    self.permissions.add(new_member, vec_set::empty<TypeName>());
}

/// Removes a member from the PermissionsGroup.
///
/// # Parameters
/// - `self`: Mutable reference to the `PermissionsGroup` state.
/// - `member`: Address of the member to be removed.
/// - `ctx`: Transaction context for permission checks.
public fun remove_member(self: &mut PermissionsGroup, member: address, ctx: &TxContext) {
    // assert caller has MemberRemover permission
    assert!(self.has_permission<MemberRemover>(ctx.sender()), ENotPermitted);
    // assert member's permissions entry exists
    assert!(self.is_member(member), EMemberNotFound);
    let member_permissions_set = self.permissions.borrow(member);
    // assert if member has PermissionsManager permission, there is at least one remaining after
    // removal
    if (member_permissions_set.contains(&type_name::with_defining_ids<PermissionsManager>())) {
        assert!(self.managers_count > 1, ELastPermissionsManager);
        self.managers_count = self.managers_count - 1;
    };
    self.permissions.remove(member);
}

// TODO7: should we allow this?
//
/// I would argue yes. Not sure if we want to issue some sort
/// of LeftTicket?
/// Let's see if we go with a MemberCap approach later on,
/// in which case we would want the user that leaves, to be able
/// to burn their MemberCap for the rebate.

/// Allows the calling member to leave the PermissionsGroup.
///
/// # Parameters
/// - `self`: Mutable reference to the `PermissionsGroup` state.
/// - `ctx`: Transaction context for permission checks.
/// # Aborts
/// - If the member does not exist in the PermissionsGroup.
/// - If the member has `PermissionsManager` permission and leaving would leave no
///   `PermissionsManager` remaining.
public fun leave(self: &mut PermissionsGroup, ctx: &TxContext) {
    let member = ctx.sender();

    // assert member's permissions entry exists
    assert!(self.is_member(member), EMemberNotFound);

    let member_permissions_set = self.permissions.borrow(member);

    // assert if member has PermissionsManager permission, there is at least one remaining after
    // removal
    if (member_permissions_set.contains(&type_name::with_defining_ids<PermissionsManager>())) {
        assert!(self.managers_count > 1, ELastPermissionsManager);
        self.managers_count = self.managers_count - 1;
    };
    self.permissions.remove(member);
}

/// Grants a new permission to an existing member.
///
/// # Type Parameters
/// - `NewPermission`: The permission type to be granted to the member.
/// # Parameters
/// - `self`: Mutable reference to the `PermissionsGroup` state.
/// - `member`: Address of the member to whom the permission will be granted.
/// - `ctx`: Transaction context for permission checks.
/// # Aborts
/// - If the caller does not have `PermissionsManager` permission.
/// - If the member does not exist in the PermissionsGroup.
public fun grant_permission<NewPermission: drop>(
    self: &mut PermissionsGroup,
    member: address,
    ctx: &TxContext,
) {
    // assert caller has PermissionsManager permission
    assert!(self.has_permission<PermissionsManager>(ctx.sender()), ENotPermitted);
    // assert member's permissions entry exists
    assert!(self.is_member(member), EMemberNotFound);
    let member_permissions_set = self.permissions.borrow_mut(member);
    member_permissions_set.insert(type_name::with_defining_ids<NewPermission>());

    // if NewPermission is PermissionsManager, increment count
    if (
        type_name::with_defining_ids<NewPermission>() == type_name::with_defining_ids<PermissionsManager>()
    ) {
        self.managers_count = self.managers_count + 1;
    };
}

/// Revokes an existing permission from a member.
///
/// # Type Parameters
/// - `ExistingPermission`: The permission type to be revoked from the member.
/// # Parameters
/// - `self`: Mutable reference to the `PermissionsGroup` state.
/// - `member`: Address of the member from whom the permission will be revoked.
/// - `ctx`: Transaction context for permission checks.
/// # Aborts
/// - If the caller does not have `PermissionsManager` permission.
/// - If the member does not exist in the permissions table.
/// - If revoking the permission would leave no `PermissionsManager` remaining.
public fun revoke_permission<ExistingPermission: drop>(
    self: &mut PermissionsGroup,
    member: address,
    ctx: &TxContext,
) {
    // assert caller has PermissionsManager permission
    assert!(self.has_permission<PermissionsManager>(ctx.sender()), ENotPermitted);

    // assert member's permissions entry exists
    assert!(self.permissions.contains(member), EMemberNotFound);

    // assert after revocation, there is at least one PermissionsManager remaining
    if (
        type_name::with_defining_ids<ExistingPermission>() == type_name::with_defining_ids<PermissionsManager>()
    ) {
        assert!(self.managers_count > 1, ELastPermissionsManager);
        self.managers_count = self.managers_count - 1;
    };

    let member_permissions_set = self.permissions.borrow_mut(member);
    member_permissions_set.remove(&type_name::with_defining_ids<ExistingPermission>());

    // If the member has no more permissions, remove their entry from the table
    if (member_permissions_set.is_empty()) {
        self.permissions.remove(member);
    };
}

/// Checks if the given address has the specified permission.
/// # Type Parameters
/// - `Permission`: The permission type to check for.
/// # Parameters
/// - `self`: Reference to the `PermissionsGroup` state.
/// - `member`: Member address to check for the specified permission.
/// # Returns
/// - `bool`: `true` if the address has the permission, `false` otherwise
public fun has_permission<Permission: drop>(self: &PermissionsGroup, member: address): bool {
    self.permissions.borrow(member).contains(&type_name::with_defining_ids<Permission>())
}

/// Checks if the given address is a member of the PermissionsGroup.
///
/// # Parameters
/// - `self`: Reference to the `PermissionsGroup` state.
/// - `member`: Address to check for membership.
/// # Returns
/// - `bool`: `true` if the address is a member, `false` otherwise
public fun is_member(self: &PermissionsGroup, member: address): bool {
    self.permissions.contains(member)
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
/// - `self`: Mutable reference to the `PermissionsGroup` state.
/// - `approval`: The JoinApproval proving the policy was satisfied (consumed).
///
/// # Aborts
/// - If the member is already in the group.
public fun add_member_with_approval<T>(
    self: &mut PermissionsGroup,
    approval: join_policy::JoinApproval<T>,
) {
    let new_member = join_policy::consume_approval(approval);
    // assert new_member is not already present
    assert!(!self.is_member(new_member), EMemberNotFound);
    // Add member with empty permissions set
    self.permissions.add(new_member, vec_set::empty<TypeName>());
}
