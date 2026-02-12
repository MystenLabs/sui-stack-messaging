
<a name="permissioned_groups_permissioned_group"></a>

# Module `permissioned_groups::permissioned_group`

Module: permissioned_group

Generic permission system for group management.


<a name="@Permissions_0"></a>

### Permissions


Core permissions (defined in this package):
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code>: Manages core permissions. Can grant/revoke PermissionsAdmin,
ExtensionPermissionsAdmin, UIDAccessor, SelfLeave. Can remove members.
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code>: Manages extension permissions defined in third-party packages.
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_UIDAccessor">UIDAccessor</a></code>: Grants access to the group's UID (&UID and &mut UID).
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_SelfLeave">SelfLeave</a></code>: Grants ability to self-remove via <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_leave">leave</a>()</code>.


<a name="@Permission_Scoping_1"></a>

### Permission Scoping


- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> can ONLY manage core permissions (from this package)
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code> can ONLY manage extension permissions (from other packages)


<a name="@Key_Concepts_2"></a>

### Key Concepts


- **Membership is defined by permissions**: A member exists if and only if they have at least
one permission
- **Granting implicitly adds**: <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_grant_permission">grant_permission</a>()</code> will automatically add a member if they
don't exist
- **Revoking may remove**: Revoking the last permission automatically removes the member from
the group


<a name="@Invariants_3"></a>

### Invariants


- At least one <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> must always exist
- Members always have at least one permission (empty permission sets are not allowed)


    -  [Permissions](#@Permissions_0)
    -  [Permission Scoping](#@Permission_Scoping_1)
    -  [Key Concepts](#@Key_Concepts_2)
    -  [Invariants](#@Invariants_3)
-  [Struct `PermissionsAdmin`](#permissioned_groups_permissioned_group_PermissionsAdmin)
-  [Struct `ExtensionPermissionsAdmin`](#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin)
-  [Struct `UIDAccessor`](#permissioned_groups_permissioned_group_UIDAccessor)
-  [Struct `SelfLeave`](#permissioned_groups_permissioned_group_SelfLeave)
-  [Struct `PermissionedGroup`](#permissioned_groups_permissioned_group_PermissionedGroup)
-  [Struct `GroupCreated`](#permissioned_groups_permissioned_group_GroupCreated)
-  [Struct `GroupDerived`](#permissioned_groups_permissioned_group_GroupDerived)
-  [Struct `MemberAdded`](#permissioned_groups_permissioned_group_MemberAdded)
-  [Struct `MemberRemoved`](#permissioned_groups_permissioned_group_MemberRemoved)
-  [Struct `PermissionsGranted`](#permissioned_groups_permissioned_group_PermissionsGranted)
-  [Struct `PermissionsRevoked`](#permissioned_groups_permissioned_group_PermissionsRevoked)
-  [Constants](#@Constants_4)
-  [Function `new`](#permissioned_groups_permissioned_group_new)
    -  [Type Parameters](#@Type_Parameters_5)
    -  [Parameters](#@Parameters_6)
    -  [Returns](#@Returns_7)
-  [Function `new_derived`](#permissioned_groups_permissioned_group_new_derived)
    -  [Type Parameters](#@Type_Parameters_8)
    -  [Parameters](#@Parameters_9)
    -  [Returns](#@Returns_10)
    -  [Aborts](#@Aborts_11)
-  [Function `grant_permission`](#permissioned_groups_permissioned_group_grant_permission)
    -  [Type Parameters](#@Type_Parameters_12)
    -  [Parameters](#@Parameters_13)
    -  [Aborts](#@Aborts_14)
-  [Function `object_grant_permission`](#permissioned_groups_permissioned_group_object_grant_permission)
    -  [Type Parameters](#@Type_Parameters_15)
    -  [Parameters](#@Parameters_16)
    -  [Aborts](#@Aborts_17)
-  [Function `remove_member`](#permissioned_groups_permissioned_group_remove_member)
    -  [Parameters](#@Parameters_18)
    -  [Aborts](#@Aborts_19)
-  [Function `object_remove_member`](#permissioned_groups_permissioned_group_object_remove_member)
    -  [Parameters](#@Parameters_20)
    -  [Aborts](#@Aborts_21)
-  [Function `revoke_permission`](#permissioned_groups_permissioned_group_revoke_permission)
    -  [Type Parameters](#@Type_Parameters_22)
    -  [Parameters](#@Parameters_23)
    -  [Aborts](#@Aborts_24)
-  [Function `object_revoke_permission`](#permissioned_groups_permissioned_group_object_revoke_permission)
    -  [Type Parameters](#@Type_Parameters_25)
    -  [Parameters](#@Parameters_26)
    -  [Aborts](#@Aborts_27)
-  [Function `has_permission`](#permissioned_groups_permissioned_group_has_permission)
    -  [Type Parameters](#@Type_Parameters_28)
    -  [Parameters](#@Parameters_29)
    -  [Returns](#@Returns_30)
-  [Function `is_member`](#permissioned_groups_permissioned_group_is_member)
    -  [Type Parameters](#@Type_Parameters_31)
    -  [Parameters](#@Parameters_32)
    -  [Returns](#@Returns_33)
-  [Function `creator`](#permissioned_groups_permissioned_group_creator)
    -  [Parameters](#@Parameters_34)
    -  [Returns](#@Returns_35)
-  [Function `uid`](#permissioned_groups_permissioned_group_uid)
-  [Function `uid_mut`](#permissioned_groups_permissioned_group_uid_mut)
-  [Function `object_uid`](#permissioned_groups_permissioned_group_object_uid)
-  [Function `object_uid_mut`](#permissioned_groups_permissioned_group_object_uid_mut)
-  [Function `leave`](#permissioned_groups_permissioned_group_leave)
-  [Function `permissions_admin_count`](#permissioned_groups_permissioned_group_permissions_admin_count)
    -  [Parameters](#@Parameters_36)
    -  [Returns](#@Returns_37)
-  [Function `is_core_permission`](#permissioned_groups_permissioned_group_is_core_permission)
-  [Function `assert_can_manage_permission`](#permissioned_groups_permissioned_group_assert_can_manage_permission)
-  [Function `safe_decrement_permissions_admin_count`](#permissioned_groups_permissioned_group_safe_decrement_permissions_admin_count)
-  [Function `internal_grant_permission`](#permissioned_groups_permissioned_group_internal_grant_permission)
-  [Function `internal_revoke_permission`](#permissioned_groups_permissioned_group_internal_revoke_permission)
-  [Macro function `internal_new`](#permissioned_groups_permissioned_group_internal_new)


<pre><code><b>use</b> <a href="../permissioned_groups/permissions_table.md#permissioned_groups_permissions_table">permissioned_groups::permissions_table</a>;
<b>use</b> <a href="../dependencies/std/address.md#std_address">std::address</a>;
<b>use</b> <a href="../dependencies/std/ascii.md#std_ascii">std::ascii</a>;
<b>use</b> <a href="../dependencies/std/bcs.md#std_bcs">std::bcs</a>;
<b>use</b> <a href="../dependencies/std/option.md#std_option">std::option</a>;
<b>use</b> <a href="../dependencies/std/string.md#std_string">std::string</a>;
<b>use</b> <a href="../dependencies/std/type_name.md#std_type_name">std::type_name</a>;
<b>use</b> <a href="../dependencies/std/vector.md#std_vector">std::vector</a>;
<b>use</b> <a href="../dependencies/sui/accumulator.md#sui_accumulator">sui::accumulator</a>;
<b>use</b> <a href="../dependencies/sui/accumulator_settlement.md#sui_accumulator_settlement">sui::accumulator_settlement</a>;
<b>use</b> <a href="../dependencies/sui/address.md#sui_address">sui::address</a>;
<b>use</b> <a href="../dependencies/sui/bcs.md#sui_bcs">sui::bcs</a>;
<b>use</b> <a href="../dependencies/sui/derived_object.md#sui_derived_object">sui::derived_object</a>;
<b>use</b> <a href="../dependencies/sui/dynamic_field.md#sui_dynamic_field">sui::dynamic_field</a>;
<b>use</b> <a href="../dependencies/sui/event.md#sui_event">sui::event</a>;
<b>use</b> <a href="../dependencies/sui/hash.md#sui_hash">sui::hash</a>;
<b>use</b> <a href="../dependencies/sui/hex.md#sui_hex">sui::hex</a>;
<b>use</b> <a href="../dependencies/sui/object.md#sui_object">sui::object</a>;
<b>use</b> <a href="../dependencies/sui/party.md#sui_party">sui::party</a>;
<b>use</b> <a href="../dependencies/sui/transfer.md#sui_transfer">sui::transfer</a>;
<b>use</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context">sui::tx_context</a>;
<b>use</b> <a href="../dependencies/sui/vec_map.md#sui_vec_map">sui::vec_map</a>;
<b>use</b> <a href="../dependencies/sui/vec_set.md#sui_vec_set">sui::vec_set</a>;
</code></pre>



<a name="permissioned_groups_permissioned_group_PermissionsAdmin"></a>

## Struct `PermissionsAdmin`

Permission to manage core permissions defined in the permissioned_groups package.
Can manage: PermissionsAdmin, ExtensionPermissionsAdmin, UIDAccessor, SelfLeave.
Cannot manage extension permissions (those from other packages).


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="permissioned_groups_permissioned_group_ExtensionPermissionsAdmin"></a>

## Struct `ExtensionPermissionsAdmin`

Permission to manage extension permissions defined in third-party packages.
Can manage permissions from OTHER packages (e.g., MessagingSender, FundsManager).
Cannot manage core permissions (PermissionsAdmin, ExtensionPermissionsAdmin, etc.).


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="permissioned_groups_permissioned_group_UIDAccessor"></a>

## Struct `UIDAccessor`

Permission to access the group's UID (&UID and &mut UID).
Enables attaching dynamic fields and using derived objects.


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_UIDAccessor">UIDAccessor</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="permissioned_groups_permissioned_group_SelfLeave"></a>

## Struct `SelfLeave`

Permission to leave the group (self-remove).
Never auto-granted — always opt-in.


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_SelfLeave">SelfLeave</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="permissioned_groups_permissioned_group_PermissionedGroup"></a>

## Struct `PermissionedGroup`

Group state mapping addresses to their granted permissions.
Parameterized by <code>T</code> to scope permissions to a specific package.


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;<b>phantom</b> T: drop&gt; <b>has</b> key, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>id: <a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a></code>
</dt>
<dd>
</dd>
<dt>
<code>permissions: <a href="../permissioned_groups/permissions_table.md#permissioned_groups_permissions_table_PermissionsTable">permissioned_groups::permissions_table::PermissionsTable</a></code>
</dt>
<dd>
 Maps member addresses (user or object) to their permission set.
 Object addresses enable <code>object_*</code> functions for third-party "actor" contracts.
</dd>
<dt>
<code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_permissions_admin_count">permissions_admin_count</a>: u64</code>
</dt>
<dd>
 Tracks <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> count to enforce at-least-one invariant.
</dd>
<dt>
<code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>: <b>address</b></code>
</dt>
<dd>
 Original creator's address
</dd>
</dl>


</details>

<a name="permissioned_groups_permissioned_group_GroupCreated"></a>

## Struct `GroupCreated`

Emitted when a new PermissionedGroup is created via <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_new">new</a></code>.


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_GroupCreated">GroupCreated</a>&lt;<b>phantom</b> T&gt; <b>has</b> <b>copy</b>, drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>group_id: <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a></code>
</dt>
<dd>
 ID of the created group.
</dd>
<dt>
<code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>: <b>address</b></code>
</dt>
<dd>
 Address of the group creator.
</dd>
</dl>


</details>

<a name="permissioned_groups_permissioned_group_GroupDerived"></a>

## Struct `GroupDerived`

Emitted when a new PermissionedGroup is created via <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_new_derived">new_derived</a></code>.


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_GroupDerived">GroupDerived</a>&lt;<b>phantom</b> T, DerivationKey: <b>copy</b>, drop&gt; <b>has</b> <b>copy</b>, drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>group_id: <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a></code>
</dt>
<dd>
 ID of the created group.
</dd>
<dt>
<code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>: <b>address</b></code>
</dt>
<dd>
 Address of the group creator.
</dd>
<dt>
<code>parent_id: <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a></code>
</dt>
<dd>
 ID of the parent object from which the group was derived.
</dd>
<dt>
<code>derivation_key: DerivationKey</code>
</dt>
<dd>
 derivation key used.
</dd>
</dl>


</details>

<a name="permissioned_groups_permissioned_group_MemberAdded"></a>

## Struct `MemberAdded`

Emitted when a new member is added to a group via grant_permission.


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberAdded">MemberAdded</a>&lt;<b>phantom</b> T&gt; <b>has</b> <b>copy</b>, drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>group_id: <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a></code>
</dt>
<dd>
 ID of the group.
</dd>
<dt>
<code>member: <b>address</b></code>
</dt>
<dd>
 Address of the new member.
</dd>
</dl>


</details>

<a name="permissioned_groups_permissioned_group_MemberRemoved"></a>

## Struct `MemberRemoved`

Emitted when a member is removed from a group.


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberRemoved">MemberRemoved</a>&lt;<b>phantom</b> T&gt; <b>has</b> <b>copy</b>, drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>group_id: <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a></code>
</dt>
<dd>
 ID of the group.
</dd>
<dt>
<code>member: <b>address</b></code>
</dt>
<dd>
 Address of the removed member.
</dd>
</dl>


</details>

<a name="permissioned_groups_permissioned_group_PermissionsGranted"></a>

## Struct `PermissionsGranted`

Emitted when permissions are granted to a member.


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsGranted">PermissionsGranted</a>&lt;<b>phantom</b> T&gt; <b>has</b> <b>copy</b>, drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>group_id: <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a></code>
</dt>
<dd>
 ID of the group.
</dd>
<dt>
<code>member: <b>address</b></code>
</dt>
<dd>
 Address of the member receiving the permissions.
</dd>
<dt>
<code>permissions: vector&lt;<a href="../dependencies/std/type_name.md#std_type_name_TypeName">std::type_name::TypeName</a>&gt;</code>
</dt>
<dd>
 Type names of the granted permissions.
</dd>
</dl>


</details>

<a name="permissioned_groups_permissioned_group_PermissionsRevoked"></a>

## Struct `PermissionsRevoked`

Emitted when permissions are revoked from a member.


<pre><code><b>public</b> <b>struct</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsRevoked">PermissionsRevoked</a>&lt;<b>phantom</b> T&gt; <b>has</b> <b>copy</b>, drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>group_id: <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a></code>
</dt>
<dd>
 ID of the group.
</dd>
<dt>
<code>member: <b>address</b></code>
</dt>
<dd>
 Address of the member losing the permissions.
</dd>
<dt>
<code>permissions: vector&lt;<a href="../dependencies/std/type_name.md#std_type_name_TypeName">std::type_name::TypeName</a>&gt;</code>
</dt>
<dd>
 Type names of the revoked permissions.
</dd>
</dl>


</details>

<a name="@Constants_4"></a>

## Constants


<a name="permissioned_groups_permissioned_group_ENotPermitted"></a>

Caller lacks the required permission to perform the operation.


<pre><code><b>const</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a>: u64 = 0;
</code></pre>



<a name="permissioned_groups_permissioned_group_EMemberNotFound"></a>

The specified address is not a member of the group.


<pre><code><b>const</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EMemberNotFound">EMemberNotFound</a>: u64 = 1;
</code></pre>



<a name="permissioned_groups_permissioned_group_ELastPermissionsAdmin"></a>

Cannot remove or revoke the last <code>Administrator</code> in the group.


<pre><code><b>const</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ELastPermissionsAdmin">ELastPermissionsAdmin</a>: u64 = 2;
</code></pre>



<a name="permissioned_groups_permissioned_group_EPermissionedGroupAlreadyExists"></a>

A derived <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a></code> already exists for the given derivation key.


<pre><code><b>const</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EPermissionedGroupAlreadyExists">EPermissionedGroupAlreadyExists</a>: u64 = 3;
</code></pre>



<a name="permissioned_groups_permissioned_group_PERMISSIONS_TABLE_DERIVATION_KEY_BYTES"></a>



<pre><code><b>const</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PERMISSIONS_TABLE_DERIVATION_KEY_BYTES">PERMISSIONS_TABLE_DERIVATION_KEY_BYTES</a>: vector&lt;u8&gt; = vector[112, 101, 114, 109, 105, 115, 115, 105, 111, 110, 115, 95, 116, 97, 98, 108, 101];
</code></pre>



<a name="permissioned_groups_permissioned_group_new"></a>

## Function `new`

Creates a new PermissionedGroup with the sender as initial admin.
Grants <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> and <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code> to creator.


<a name="@Type_Parameters_5"></a>

### Type Parameters

- <code>T</code>: Package witness type to scope permissions


<a name="@Parameters_6"></a>

### Parameters

- <code>_witness</code>: Instance of witness type <code>T</code> (proves caller owns the type)
- <code>ctx</code>: Transaction context


<a name="@Returns_7"></a>

### Returns

A new <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;</code> with sender having <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> and
<code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_new">new</a>&lt;T: drop&gt;(_witness: T, ctx: &<b>mut</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_new">new</a>&lt;T: drop&gt;(_witness: T, ctx: &<b>mut</b> TxContext): <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt; {
    <b>let</b> group_uid = object::new(ctx);
    <b>let</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a> = ctx.sender();
    event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_GroupCreated">GroupCreated</a>&lt;T&gt; {
        group_id: group_uid.to_inner(),
        <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>,
    });
    <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_new">internal_new</a>!(group_uid, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>)
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_new_derived"></a>

## Function `new_derived`

Creates a new derived PermissionedGroup with deterministic address.
Grants <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> and <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code> to creator.


<a name="@Type_Parameters_8"></a>

### Type Parameters

- <code>T</code>: Package witness type to scope permissions
- <code>DerivationKey</code>: Key type for address derivation


<a name="@Parameters_9"></a>

### Parameters

- <code>_witness</code>: Instance of witness type <code>T</code> (proves caller owns the type)
- <code>derivation_uid</code>: Mutable reference to the parent UID for derivation
- <code>derivation_key</code>: Key used for deterministic address derivation
- <code>ctx</code>: Transaction context


<a name="@Returns_10"></a>

### Returns

A new <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;</code> with derived address.


<a name="@Aborts_11"></a>

### Aborts

- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EPermissionedGroupAlreadyExists">EPermissionedGroupAlreadyExists</a></code>: if derived address is already claimed


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_new_derived">new_derived</a>&lt;T: drop, DerivationKey: <b>copy</b>, drop, store&gt;(_witness: T, derivation_uid: &<b>mut</b> <a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>, derivation_key: DerivationKey, ctx: &<b>mut</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_new_derived">new_derived</a>&lt;T: drop, DerivationKey: <b>copy</b> + drop + store&gt;(
    _witness: T,
    derivation_uid: &<b>mut</b> UID,
    derivation_key: DerivationKey,
    ctx: &<b>mut</b> TxContext,
): <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt; {
    <b>assert</b>!(
        !derived_object::exists(derivation_uid, derivation_key),
        <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EPermissionedGroupAlreadyExists">EPermissionedGroupAlreadyExists</a>,
    );
    <b>let</b> group_uid = derived_object::claim(derivation_uid, derivation_key);
    <b>let</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a> = ctx.sender();
    event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_GroupDerived">GroupDerived</a>&lt;T, DerivationKey&gt; {
        group_id: group_uid.to_inner(),
        <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>: ctx.sender(),
        parent_id: object::uid_to_inner(derivation_uid),
        derivation_key,
    });
    <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_new">internal_new</a>!(group_uid, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>)
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_grant_permission"></a>

## Function `grant_permission`

Grants a permission to a member.
If the member doesn't exist, they are automatically added to the group.
Emits both <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberAdded">MemberAdded</a></code> (if new) and <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsGranted">PermissionsGranted</a></code> events.

Permission requirements:
- Core permissions: caller must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code>
- Extension permissions: caller must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code>


<a name="@Type_Parameters_12"></a>

### Type Parameters

- <code>T</code>: Package witness type
- <code>NewPermission</code>: Permission type to grant


<a name="@Parameters_13"></a>

### Parameters

- <code>self</code>: Mutable reference to the PermissionedGroup
- <code>member</code>: Address of the member to grant permission to
- <code>ctx</code>: Transaction context


<a name="@Aborts_14"></a>

### Aborts

- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a></code>: if caller doesn't have appropriate manager permission


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_grant_permission">grant_permission</a>&lt;T: drop, NewPermission: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_grant_permission">grant_permission</a>&lt;T: drop, NewPermission: drop&gt;(
    self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;,
    member: <b>address</b>,
    ctx: &TxContext,
) {
    // Verify caller <b>has</b> permission to grant this permission type
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_assert_can_manage_permission">assert_can_manage_permission</a>&lt;T, NewPermission&gt;(ctx.sender());
    // <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_grant_permission">internal_grant_permission</a> handles member addition and permission granting
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_grant_permission">internal_grant_permission</a>&lt;T, NewPermission&gt;(member);
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_object_grant_permission"></a>

## Function `object_grant_permission`

Grants a permission to a recipient via an actor object.
Enables third-party contracts to grant permissions with custom logic.
If the recipient is not already a member, they are automatically added.

Permission requirements:
- Core permissions: actor must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code>
- Extension permissions: actor must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code>


<a name="@Type_Parameters_15"></a>

### Type Parameters

- <code>T</code>: Package witness type
- <code>NewPermission</code>: Permission type to grant


<a name="@Parameters_16"></a>

### Parameters

- <code>self</code>: Mutable reference to the PermissionedGroup
- <code>actor_object</code>: UID of the actor object with appropriate manager permission
- <code>recipient</code>: Address of the member to receive the permission


<a name="@Aborts_17"></a>

### Aborts

- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a></code>: if actor_object doesn't have appropriate manager permission


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_object_grant_permission">object_grant_permission</a>&lt;T: drop, NewPermission: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, actor_object: &<a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>, recipient: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_object_grant_permission">object_grant_permission</a>&lt;T: drop, NewPermission: drop&gt;(
    self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;,
    actor_object: &UID,
    recipient: <b>address</b>,
) {
    <b>let</b> actor_address = actor_object.to_address();
    // Verify actor <b>has</b> permission to grant this permission type
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_assert_can_manage_permission">assert_can_manage_permission</a>&lt;T, NewPermission&gt;(actor_address);
    // <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_grant_permission">internal_grant_permission</a> handles member addition and permission granting
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_grant_permission">internal_grant_permission</a>&lt;T, NewPermission&gt;(recipient);
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_remove_member"></a>

## Function `remove_member`

Removes a member from the PermissionedGroup.
Requires <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> permission as this is a powerful admin operation.


<a name="@Parameters_18"></a>

### Parameters

- <code>self</code>: Mutable reference to the PermissionedGroup
- <code>member</code>: Address of the member to remove
- <code>ctx</code>: Transaction context


<a name="@Aborts_19"></a>

### Aborts

- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a></code>: if caller doesn't have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> permission
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EMemberNotFound">EMemberNotFound</a></code>: if member doesn't exist
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ELastPermissionsAdmin">ELastPermissionsAdmin</a></code>: if removing would leave no PermissionsAdmins


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_remove_member">remove_member</a>&lt;T: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_remove_member">remove_member</a>&lt;T: drop&gt;(
    self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;,
    member: <b>address</b>,
    ctx: &TxContext,
) {
    <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a>&gt;(ctx.sender()), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a>);
    <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_member">is_member</a>&lt;T&gt;(member), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EMemberNotFound">EMemberNotFound</a>);
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_safe_decrement_permissions_admin_count">safe_decrement_permissions_admin_count</a>(member);
    self.permissions.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_remove_member">remove_member</a>(member);
    event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberRemoved">MemberRemoved</a>&lt;T&gt; {
        group_id: object::id(self),
        member,
    });
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_object_remove_member"></a>

## Function `object_remove_member`

Removes a member from the group via an actor object.
Enables third-party contracts to implement custom leave logic.
The actor object must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> permission on the group.


<a name="@Parameters_20"></a>

### Parameters

- <code>self</code>: Mutable reference to the PermissionedGroup
- <code>actor_object</code>: UID of the actor object with <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> permission
- <code>member</code>: Address of the member to remove


<a name="@Aborts_21"></a>

### Aborts

- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a></code>: if actor_object doesn't have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> permission
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EMemberNotFound">EMemberNotFound</a></code>: if member is not a member
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ELastPermissionsAdmin">ELastPermissionsAdmin</a></code>: if removing would leave no PermissionsAdmins


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_object_remove_member">object_remove_member</a>&lt;T: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, actor_object: &<a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>, member: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_object_remove_member">object_remove_member</a>&lt;T: drop&gt;(
    self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;,
    actor_object: &UID,
    member: <b>address</b>,
) {
    <b>let</b> actor_address = actor_object.to_address();
    <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a>&gt;(actor_address), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a>);
    <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_member">is_member</a>&lt;T&gt;(member), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EMemberNotFound">EMemberNotFound</a>);
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_safe_decrement_permissions_admin_count">safe_decrement_permissions_admin_count</a>(member);
    self.permissions.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_remove_member">remove_member</a>(member);
    event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberRemoved">MemberRemoved</a>&lt;T&gt; {
        group_id: object::id(self),
        member,
    });
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_revoke_permission"></a>

## Function `revoke_permission`

Revokes a permission from a member.
If this is the member's last permission, they are automatically removed from the group.
Emits <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsRevoked">PermissionsRevoked</a></code> and potentially <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberRemoved">MemberRemoved</a></code> events.

Permission requirements:
- Core permissions: caller must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code>
- Extension permissions: caller must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code>


<a name="@Type_Parameters_22"></a>

### Type Parameters

- <code>T</code>: Package witness type
- <code>ExistingPermission</code>: Permission type to revoke


<a name="@Parameters_23"></a>

### Parameters

- <code>self</code>: Mutable reference to the PermissionedGroup
- <code>member</code>: Address of the member to revoke permission from
- <code>ctx</code>: Transaction context


<a name="@Aborts_24"></a>

### Aborts

- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a></code>: if caller doesn't have appropriate manager permission
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EMemberNotFound">EMemberNotFound</a></code>: if member doesn't exist
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ELastPermissionsAdmin">ELastPermissionsAdmin</a></code>: if revoking <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> would leave no admins


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_revoke_permission">revoke_permission</a>&lt;T: drop, ExistingPermission: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_revoke_permission">revoke_permission</a>&lt;T: drop, ExistingPermission: drop&gt;(
    self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;,
    member: <b>address</b>,
    ctx: &TxContext,
) {
    // Verify caller <b>has</b> permission to revoke this permission type
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_assert_can_manage_permission">assert_can_manage_permission</a>&lt;T, ExistingPermission&gt;(ctx.sender());
    <b>assert</b>!(self.permissions.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_member">is_member</a>(member), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EMemberNotFound">EMemberNotFound</a>);
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_revoke_permission">internal_revoke_permission</a>&lt;T, ExistingPermission&gt;(member);
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_object_revoke_permission"></a>

## Function `object_revoke_permission`

Revokes a permission from a member via an actor object.
Enables third-party contracts to revoke permissions with custom logic.
If this is the member's last permission, they are automatically removed from the group.

Permission requirements:
- Core permissions: actor must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code>
- Extension permissions: actor must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code>


<a name="@Type_Parameters_25"></a>

### Type Parameters

- <code>T</code>: Package witness type
- <code>ExistingPermission</code>: Permission type to revoke


<a name="@Parameters_26"></a>

### Parameters

- <code>self</code>: Mutable reference to the PermissionedGroup
- <code>actor_object</code>: UID of the actor object with appropriate manager permission
- <code>member</code>: Address of the member to revoke permission from


<a name="@Aborts_27"></a>

### Aborts

- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a></code>: if actor_object doesn't have appropriate manager permission
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EMemberNotFound">EMemberNotFound</a></code>: if member is not a member
- <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ELastPermissionsAdmin">ELastPermissionsAdmin</a></code>: if revoking <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> would leave no admins


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_object_revoke_permission">object_revoke_permission</a>&lt;T: drop, ExistingPermission: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, actor_object: &<a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>, member: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_object_revoke_permission">object_revoke_permission</a>&lt;T: drop, ExistingPermission: drop&gt;(
    self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;,
    actor_object: &UID,
    member: <b>address</b>,
) {
    <b>let</b> actor_address = actor_object.to_address();
    // Verify actor <b>has</b> permission to revoke this permission type
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_assert_can_manage_permission">assert_can_manage_permission</a>&lt;T, ExistingPermission&gt;(actor_address);
    <b>assert</b>!(self.permissions.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_member">is_member</a>(member), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_EMemberNotFound">EMemberNotFound</a>);
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_revoke_permission">internal_revoke_permission</a>&lt;T, ExistingPermission&gt;(member);
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_has_permission"></a>

## Function `has_permission`

Checks if the given address has the specified permission.


<a name="@Type_Parameters_28"></a>

### Type Parameters

- <code>T</code>: Package witness type
- <code>Permission</code>: Permission type to check


<a name="@Parameters_29"></a>

### Parameters

- <code>self</code>: Reference to the PermissionedGroup
- <code>member</code>: Address to check


<a name="@Returns_30"></a>

### Returns

<code><b>true</b></code> if the address has the permission, <code><b>false</b></code> otherwise.


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T: drop, Permission: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, member: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T: drop, Permission: drop&gt;(
    self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;,
    member: <b>address</b>,
): bool {
    self.permissions.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>(member, &type_name::with_defining_ids&lt;Permission&gt;())
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_is_member"></a>

## Function `is_member`

Checks if the given address is a member of the group.


<a name="@Type_Parameters_31"></a>

### Type Parameters

- <code>T</code>: Package witness type


<a name="@Parameters_32"></a>

### Parameters

- <code>self</code>: Reference to the PermissionedGroup
- <code>member</code>: Address to check


<a name="@Returns_33"></a>

### Returns

<code><b>true</b></code> if the address is a member, <code><b>false</b></code> otherwise.


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_member">is_member</a>&lt;T: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, member: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_member">is_member</a>&lt;T: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;, member: <b>address</b>): bool {
    self.permissions.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_member">is_member</a>(member)
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_creator"></a>

## Function `creator`

Returns the creator's address of the PermissionedGroup.


<a name="@Parameters_34"></a>

### Parameters

- <code>self</code>: Reference to the PermissionedGroup


<a name="@Returns_35"></a>

### Returns

The address of the creator.


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>&lt;T: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>&lt;T: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;): <b>address</b> {
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_uid"></a>

## Function `uid`

Returns a reference to the group's UID. Requires <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_UIDAccessor">UIDAccessor</a></code> permission.


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_uid">uid</a>&lt;T: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): &<a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_uid">uid</a>&lt;T: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;, ctx: &TxContext): &UID {
    <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_UIDAccessor">UIDAccessor</a>&gt;(ctx.sender()), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a>);
    &self.id
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_uid_mut"></a>

## Function `uid_mut`

Returns a mutable reference to the group's UID. Requires <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_UIDAccessor">UIDAccessor</a></code> permission.


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_uid_mut">uid_mut</a>&lt;T: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): &<b>mut</b> <a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_uid_mut">uid_mut</a>&lt;T: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;, ctx: &TxContext): &<b>mut</b> UID {
    <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_UIDAccessor">UIDAccessor</a>&gt;(ctx.sender()), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a>);
    &<b>mut</b> self.id
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_object_uid"></a>

## Function `object_uid`

Object-actor variant of <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_uid">uid</a>()</code>. Requires <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_UIDAccessor">UIDAccessor</a></code> permission on the actor.


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_object_uid">object_uid</a>&lt;T: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, actor_object: &<a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>): &<a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_object_uid">object_uid</a>&lt;T: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;, actor_object: &UID): &UID {
    <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_UIDAccessor">UIDAccessor</a>&gt;(actor_object.to_address()), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a>);
    &self.id
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_object_uid_mut"></a>

## Function `object_uid_mut`

Object-actor variant of <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_uid_mut">uid_mut</a>()</code>. Requires <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_UIDAccessor">UIDAccessor</a></code> permission on the actor.


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_object_uid_mut">object_uid_mut</a>&lt;T: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, actor_object: &<a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>): &<b>mut</b> <a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_object_uid_mut">object_uid_mut</a>&lt;T: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;, actor_object: &UID): &<b>mut</b> UID {
    <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_UIDAccessor">UIDAccessor</a>&gt;(actor_object.to_address()), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a>);
    &<b>mut</b> self.id
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_leave"></a>

## Function `leave`

Allows the sender to leave the group. Requires <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_SelfLeave">SelfLeave</a></code> permission.
Removes all permissions atomically. Prevented if sender is the last PermissionsAdmin.


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_leave">leave</a>&lt;T: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_leave">leave</a>&lt;T: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;, ctx: &TxContext) {
    <b>let</b> member = ctx.sender();
    <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_SelfLeave">SelfLeave</a>&gt;(member), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a>);
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_safe_decrement_permissions_admin_count">safe_decrement_permissions_admin_count</a>(member);
    self.permissions.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_remove_member">remove_member</a>(member);
    event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberRemoved">MemberRemoved</a>&lt;T&gt; {
        group_id: object::id(self),
        member,
    });
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_permissions_admin_count"></a>

## Function `permissions_admin_count`

Returns the number of <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code>s in the PermissionedGroup.


<a name="@Parameters_36"></a>

### Parameters

- <code>self</code>: Reference to the PermissionedGroup


<a name="@Returns_37"></a>

### Returns

The count of <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code>s.


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_permissions_admin_count">permissions_admin_count</a>&lt;T: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_permissions_admin_count">permissions_admin_count</a>&lt;T: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;): u64 {
    self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_permissions_admin_count">permissions_admin_count</a>
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_is_core_permission"></a>

## Function `is_core_permission`

Returns true if Permission is defined in the permissioned_groups package.


<pre><code><b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_core_permission">is_core_permission</a>&lt;Permission: drop&gt;(): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_core_permission">is_core_permission</a>&lt;Permission: drop&gt;(): bool {
    type_name::original_id&lt;Permission&gt;() == type_name::original_id&lt;<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a>&gt;()
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_assert_can_manage_permission"></a>

## Function `assert_can_manage_permission`

Asserts that the manager has permission to manage (grant/revoke) the specified permission type.
- Core permissions (from this package): manager must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code>
- Extension permissions (from other packages): manager must have <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code>


<pre><code><b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_assert_can_manage_permission">assert_can_manage_permission</a>&lt;T: drop, Permission: drop&gt;(self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, manager: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_assert_can_manage_permission">assert_can_manage_permission</a>&lt;T: drop, Permission: drop&gt;(
    self: &<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;,
    manager: <b>address</b>,
) {
    <b>if</b> (<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_core_permission">is_core_permission</a>&lt;Permission&gt;()) {
        // Core permissions → only <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a>
        <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a>&gt;(manager), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a>);
    } <b>else</b> {
        // Extension permissions → only <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a>
        <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>&lt;T, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a>&gt;(manager), <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ENotPermitted">ENotPermitted</a>);
    };
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_safe_decrement_permissions_admin_count"></a>

## Function `safe_decrement_permissions_admin_count`

Decrements permissions_admin_count if member has <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code>.
Used when revoking <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> permission or removing a member.
Aborts if this would leave no PermissionsAdmins.


<pre><code><b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_safe_decrement_permissions_admin_count">safe_decrement_permissions_admin_count</a>&lt;T: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, member: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_safe_decrement_permissions_admin_count">safe_decrement_permissions_admin_count</a>&lt;T: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;, member: <b>address</b>) {
    <b>if</b> (self.permissions.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_has_permission">has_permission</a>(member, &type_name::with_defining_ids&lt;<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a>&gt;())) {
        <b>assert</b>!(self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_permissions_admin_count">permissions_admin_count</a> &gt; 1, <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ELastPermissionsAdmin">ELastPermissionsAdmin</a>);
        self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_permissions_admin_count">permissions_admin_count</a> = self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_permissions_admin_count">permissions_admin_count</a> - 1;
    };
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_internal_grant_permission"></a>

## Function `internal_grant_permission`

Internal helper to grant a permission to a member.
Adds the member if they don't exist, then grants the permission.
Increments permissions_admin_count if granting <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code>.
Emits <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberAdded">MemberAdded</a></code> event if member is new.


<pre><code><b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_grant_permission">internal_grant_permission</a>&lt;T: drop, NewPermission: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, member: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_grant_permission">internal_grant_permission</a>&lt;T: drop, NewPermission: drop&gt;(
    self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;,
    member: <b>address</b>,
) {
    <b>let</b> permission_type = type_name::with_defining_ids&lt;NewPermission&gt;();
    <b>if</b> (self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_is_member">is_member</a>(member)) {
        self.permissions.add_permission(member, permission_type);
    } <b>else</b> {
        self.permissions.add_member(member, vec_set::singleton(permission_type));
        event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberAdded">MemberAdded</a>&lt;T&gt; {
            group_id: object::id(self),
            member,
        });
    };
    <b>if</b> (permission_type == type_name::with_defining_ids&lt;<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a>&gt;()) {
        self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_permissions_admin_count">permissions_admin_count</a> = self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_permissions_admin_count">permissions_admin_count</a> + 1;
    };
    event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsGranted">PermissionsGranted</a>&lt;T&gt; {
        group_id: object::id(self),
        member,
        permissions: vector[permission_type],
    });
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_internal_revoke_permission"></a>

## Function `internal_revoke_permission`

Internal helper to revoke a permission from a PermissionedGroup member.
If this is the member's last permission, they are removed from the group.


<pre><code><b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_revoke_permission">internal_revoke_permission</a>&lt;T: drop, ExistingPermission: drop&gt;(self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, member: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_revoke_permission">internal_revoke_permission</a>&lt;T: drop, ExistingPermission: drop&gt;(
    self: &<b>mut</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;T&gt;,
    member: <b>address</b>,
) {
    <b>let</b> permission_type = type_name::with_defining_ids&lt;ExistingPermission&gt;();
    // Check <b>if</b> revoking <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a>
    <b>if</b> (permission_type == type_name::with_defining_ids&lt;<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a>&gt;()) {
        self.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_safe_decrement_permissions_admin_count">safe_decrement_permissions_admin_count</a>(member);
    };
    // Revoke the permission
    <b>let</b> member_permissions_set = self.permissions.remove_permission(member, &permission_type);
    event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsRevoked">PermissionsRevoked</a>&lt;T&gt; {
        group_id: object::id(self),
        member,
        permissions: vector[type_name::with_defining_ids&lt;ExistingPermission&gt;()],
    });
    // If member <b>has</b> no permissions left, remove them from the group
    <b>if</b> (member_permissions_set.is_empty()) {
        self.permissions.<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_remove_member">remove_member</a>(member);
        event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberRemoved">MemberRemoved</a>&lt;T&gt; {
            group_id: object::id(self),
            member,
        });
    };
}
</code></pre>



</details>

<a name="permissioned_groups_permissioned_group_internal_new"></a>

## Macro function `internal_new`

Shared initialization logic for <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_new">new</a></code> and <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_new_derived">new_derived</a></code>.
Creates a <code>PermissionsTable</code>, adds the creator with <code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a></code> and
<code><a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a></code>, and emits the initial events.


<pre><code><b>macro</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_new">internal_new</a>&lt;$T: drop&gt;($group_uid: <a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>, $<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>: <b>address</b>): <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">permissioned_groups::permissioned_group::PermissionedGroup</a>&lt;$T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>macro</b> <b>fun</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_internal_new">internal_new</a>&lt;$T: drop&gt;($group_uid: UID, $<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>: <b>address</b>): <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;$T&gt; {
    <b>let</b> <b>mut</b> group_uid = $group_uid;
    <b>let</b> <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a> = $<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>;
    // Initialize <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a> with <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a> and <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a>
    <b>let</b> <b>mut</b> creator_permissions = vec_set::empty&lt;TypeName&gt;();
    creator_permissions.insert(type_name::with_defining_ids&lt;<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsAdmin">PermissionsAdmin</a>&gt;());
    creator_permissions.insert(type_name::with_defining_ids&lt;<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_ExtensionPermissionsAdmin">ExtensionPermissionsAdmin</a>&gt;());
    <b>let</b> <b>mut</b> <a href="../permissioned_groups/permissions_table.md#permissioned_groups_permissions_table">permissions_table</a> = <a href="../permissioned_groups/permissions_table.md#permissioned_groups_permissions_table_new_derived">permissions_table::new_derived</a>(
        &<b>mut</b> group_uid,
        <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PERMISSIONS_TABLE_DERIVATION_KEY_BYTES">PERMISSIONS_TABLE_DERIVATION_KEY_BYTES</a>.to_string(),
    );
    <a href="../permissioned_groups/permissions_table.md#permissioned_groups_permissions_table">permissions_table</a>.add_member(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>, creator_permissions);
    <b>let</b> group = <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionedGroup">PermissionedGroup</a>&lt;$T&gt; {
        id: group_uid,
        permissions: <a href="../permissioned_groups/permissions_table.md#permissioned_groups_permissions_table">permissions_table</a>,
        <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_permissions_admin_count">permissions_admin_count</a>: 1,
        <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>,
    };
    // Emit <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberAdded">MemberAdded</a> event <b>for</b> the <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a> (they are the first member)
    event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_MemberAdded">MemberAdded</a>&lt;$T&gt; {
        group_id: object::id(&group),
        member: <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>,
    });
    // Emit <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsGranted">PermissionsGranted</a> event <b>for</b> the <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>'s initial permissions
    // This allows event subscribers (like relayers) to track initial admin permissions
    event::emit(<a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_PermissionsGranted">PermissionsGranted</a>&lt;$T&gt; {
        group_id: object::id(&group),
        member: <a href="../permissioned_groups/permissioned_group.md#permissioned_groups_permissioned_group_creator">creator</a>,
        permissions: creator_permissions.into_keys(),
    });
    group
}
</code></pre>



</details>
