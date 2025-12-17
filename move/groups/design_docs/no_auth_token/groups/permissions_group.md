
<a name="groups_permissions_group"></a>

# Module `groups::permissions_group`

Module: permissions_group

TODO1: It might make more sense to just have PermissionsGranter and PermissionsRevoker
We DO want to have separate permissions for adding/removing because removing a member is
a more privileged/dangerous operation than adding a member.
So, I propose to either have PermissionsManager + separate MemberAdder/MemberRemover
Or just PermissionsGranter + PermissionsRevoker
For now, we will keep PermissionsManager + MemberAdder/MemberRemover

TODO2: we currently check and ensure there is always at least one PermissionsManager,
Should we also check for at least one MemberAdder and one MemberRemover?
I guess this is where it starts getting ugly having 3 separate permissions instead of just
granter/revoker. (of course a single PermissionsManager would be even simpler, but as mentioned
above
less flexible. And since we plan on offering this as a library, flexibility is important.)
One other option is to not expose add_member/remove_member functions at all, and leave the
implementation
and gating of those functions to the user of the library.

TODO3: Should we keep the assertions in the functions, or leave the responsibility to the
developer using
this library? I believe it would be ok, if we manage to implement the typed_witness
Auth<Permission> token
pattern. But, until then, I believe we should handle the assertions in this library.


-  [Struct `PermissionsManager`](#groups_permissions_group_PermissionsManager)
-  [Struct `MemberAdder`](#groups_permissions_group_MemberAdder)
-  [Struct `MemberRemover`](#groups_permissions_group_MemberRemover)
-  [Struct `PermissionsGroup`](#groups_permissions_group_PermissionsGroup)
-  [Constants](#@Constants_0)
-  [Function `new`](#groups_permissions_group_new)
    -  [Parameters](#@Parameters_1)
    -  [Returns](#@Returns_2)
-  [Function `add_member`](#groups_permissions_group_add_member)
    -  [Parameters](#@Parameters_3)
    -  [Aborts](#@Aborts_4)
-  [Function `remove_member`](#groups_permissions_group_remove_member)
    -  [Parameters](#@Parameters_5)
-  [Function `leave`](#groups_permissions_group_leave)
    -  [Parameters](#@Parameters_6)
    -  [Aborts](#@Aborts_7)
-  [Function `grant_permission`](#groups_permissions_group_grant_permission)
    -  [Type Parameters](#@Type_Parameters_8)
    -  [Parameters](#@Parameters_9)
    -  [Aborts](#@Aborts_10)
-  [Function `revoke_permission`](#groups_permissions_group_revoke_permission)
    -  [Type Parameters](#@Type_Parameters_11)
    -  [Parameters](#@Parameters_12)
    -  [Aborts](#@Aborts_13)
-  [Function `has_permission`](#groups_permissions_group_has_permission)
    -  [Type Parameters](#@Type_Parameters_14)
    -  [Parameters](#@Parameters_15)
    -  [Returns](#@Returns_16)
-  [Function `is_member`](#groups_permissions_group_is_member)
    -  [Parameters](#@Parameters_17)
    -  [Returns](#@Returns_18)
-  [Function `add_member_with_approval`](#groups_permissions_group_add_member_with_approval)
    -  [Type Parameters](#@Type_Parameters_19)
    -  [Parameters](#@Parameters_20)
    -  [Aborts](#@Aborts_21)


<pre><code><b>use</b> <a href="../groups/join_policy.md#groups_join_policy">groups::join_policy</a>;
<b>use</b> <a href="../dependencies/std/address.md#std_address">std::address</a>;
<b>use</b> <a href="../dependencies/std/ascii.md#std_ascii">std::ascii</a>;
<b>use</b> <a href="../dependencies/std/bcs.md#std_bcs">std::bcs</a>;
<b>use</b> <a href="../dependencies/std/option.md#std_option">std::option</a>;
<b>use</b> <a href="../dependencies/std/string.md#std_string">std::string</a>;
<b>use</b> <a href="../dependencies/std/type_name.md#std_type_name">std::type_name</a>;
<b>use</b> <a href="../dependencies/std/vector.md#std_vector">std::vector</a>;
<b>use</b> <a href="../dependencies/sui/address.md#sui_address">sui::address</a>;
<b>use</b> <a href="../dependencies/sui/bag.md#sui_bag">sui::bag</a>;
<b>use</b> <a href="../dependencies/sui/dynamic_field.md#sui_dynamic_field">sui::dynamic_field</a>;
<b>use</b> <a href="../dependencies/sui/hex.md#sui_hex">sui::hex</a>;
<b>use</b> <a href="../dependencies/sui/object.md#sui_object">sui::object</a>;
<b>use</b> <a href="../dependencies/sui/package.md#sui_package">sui::package</a>;
<b>use</b> <a href="../dependencies/sui/party.md#sui_party">sui::party</a>;
<b>use</b> <a href="../dependencies/sui/table.md#sui_table">sui::table</a>;
<b>use</b> <a href="../dependencies/sui/transfer.md#sui_transfer">sui::transfer</a>;
<b>use</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context">sui::tx_context</a>;
<b>use</b> <a href="../dependencies/sui/types.md#sui_types">sui::types</a>;
<b>use</b> <a href="../dependencies/sui/vec_map.md#sui_vec_map">sui::vec_map</a>;
<b>use</b> <a href="../dependencies/sui/vec_set.md#sui_vec_set">sui::vec_set</a>;
</code></pre>



<a name="groups_permissions_group_PermissionsManager"></a>

## Struct `PermissionsManager`

Witness type representing the permission to grant or revoke permissions.


<pre><code><b>public</b> <b>struct</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="groups_permissions_group_MemberAdder"></a>

## Struct `MemberAdder`

Witness type representing the permission to add members.


<pre><code><b>public</b> <b>struct</b> <a href="../groups/permissions_group.md#groups_permissions_group_MemberAdder">MemberAdder</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="groups_permissions_group_MemberRemover"></a>

## Struct `MemberRemover`

Witness type representing the permission to remove members.


<pre><code><b>public</b> <b>struct</b> <a href="../groups/permissions_group.md#groups_permissions_group_MemberRemover">MemberRemover</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="groups_permissions_group_PermissionsGroup"></a>

## Struct `PermissionsGroup`

Authorization state mapping addresses to their granted permissions
represented as TypeNames.


<pre><code><b>public</b> <b>struct</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a> <b>has</b> store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>permissions: <a href="../dependencies/sui/table.md#sui_table_Table">sui::table::Table</a>&lt;<b>address</b>, <a href="../dependencies/sui/vec_set.md#sui_vec_set_VecSet">sui::vec_set::VecSet</a>&lt;<a href="../dependencies/std/type_name.md#std_type_name_TypeName">std::type_name::TypeName</a>&gt;&gt;</code>
</dt>
<dd>
</dd>
<dt>
<code>managers_count: u64</code>
</dt>
<dd>
</dd>
</dl>


</details>

<a name="@Constants_0"></a>

## Constants


<a name="groups_permissions_group_ENotPermitted"></a>



<pre><code><b>const</b> <a href="../groups/permissions_group.md#groups_permissions_group_ENotPermitted">ENotPermitted</a>: u64 = 0;
</code></pre>



<a name="groups_permissions_group_EMemberNotFound"></a>



<pre><code><b>const</b> <a href="../groups/permissions_group.md#groups_permissions_group_EMemberNotFound">EMemberNotFound</a>: u64 = 1;
</code></pre>



<a name="groups_permissions_group_ELastPermissionsManager"></a>



<pre><code><b>const</b> <a href="../groups/permissions_group.md#groups_permissions_group_ELastPermissionsManager">ELastPermissionsManager</a>: u64 = 2;
</code></pre>



<a name="groups_permissions_group_new"></a>

## Function `new`

Creates a new PermissionsGroup with the transaction sender as the initial
manager, adder, and remover.


<a name="@Parameters_1"></a>

### Parameters

- <code>ctx</code>: Mutable transaction context for the table creation.


<a name="@Returns_2"></a>

### Returns

- A new <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a></code> object with the sender having all managing permissions.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_new">new</a>(ctx: &<b>mut</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">groups::permissions_group::PermissionsGroup</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_new">new</a>(ctx: &<b>mut</b> TxContext): <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a> {
    <b>let</b> <b>mut</b> creator_permissions_set = vec_set::empty&lt;TypeName&gt;();
    creator_permissions_set.insert(type_name::with_defining_ids&lt;<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a>&gt;());
    creator_permissions_set.insert(type_name::with_defining_ids&lt;<a href="../groups/permissions_group.md#groups_permissions_group_MemberAdder">MemberAdder</a>&gt;());
    creator_permissions_set.insert(type_name::with_defining_ids&lt;<a href="../groups/permissions_group.md#groups_permissions_group_MemberRemover">MemberRemover</a>&gt;());
    <b>let</b> <b>mut</b> permissions_table = table::new&lt;<b>address</b>, VecSet&lt;TypeName&gt;&gt;(ctx);
    permissions_table.add(ctx.sender(), creator_permissions_set);
    <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a> {
        permissions: permissions_table,
        managers_count: 1,
    }
}
</code></pre>



</details>

<a name="groups_permissions_group_add_member"></a>

## Function `add_member`

Adds a new member with no initial permissions.
The caller must have MemberAdder permission.
After adding, use <code><a href="../groups/permissions_group.md#groups_permissions_group_grant_permission">grant_permission</a></code> to assign permissions to the new member.


<a name="@Parameters_3"></a>

### Parameters

- <code>self</code>: Mutable reference to the <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a></code> state.
- <code>new_member</code>: Address of the new member to be added.
- <code>ctx</code>: Transaction context for permission checks.


<a name="@Aborts_4"></a>

### Aborts

- If caller does not have MemberAdder permission.
- If new_member is already a member.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_add_member">add_member</a>(self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">groups::permissions_group::PermissionsGroup</a>, new_member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_add_member">add_member</a>(self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a>, new_member: <b>address</b>, ctx: &TxContext) {
    // <b>assert</b> caller <b>has</b> <a href="../groups/permissions_group.md#groups_permissions_group_MemberAdder">MemberAdder</a> permission
    <b>assert</b>!(self.<a href="../groups/permissions_group.md#groups_permissions_group_has_permission">has_permission</a>&lt;<a href="../groups/permissions_group.md#groups_permissions_group_MemberAdder">MemberAdder</a>&gt;(ctx.sender()), <a href="../groups/permissions_group.md#groups_permissions_group_ENotPermitted">ENotPermitted</a>);
    // <b>assert</b> new_member is not already present
    <b>assert</b>!(!self.<a href="../groups/permissions_group.md#groups_permissions_group_is_member">is_member</a>(new_member), <a href="../groups/permissions_group.md#groups_permissions_group_EMemberNotFound">EMemberNotFound</a>);
    // Add member with empty permissions set
    self.permissions.add(new_member, vec_set::empty&lt;TypeName&gt;());
}
</code></pre>



</details>

<a name="groups_permissions_group_remove_member"></a>

## Function `remove_member`

Removes a member from the PermissionsGroup.


<a name="@Parameters_5"></a>

### Parameters

- <code>self</code>: Mutable reference to the <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a></code> state.
- <code>member</code>: Address of the member to be removed.
- <code>ctx</code>: Transaction context for permission checks.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_remove_member">remove_member</a>(self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">groups::permissions_group::PermissionsGroup</a>, member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_remove_member">remove_member</a>(self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a>, member: <b>address</b>, ctx: &TxContext) {
    // <b>assert</b> caller <b>has</b> <a href="../groups/permissions_group.md#groups_permissions_group_MemberRemover">MemberRemover</a> permission
    <b>assert</b>!(self.<a href="../groups/permissions_group.md#groups_permissions_group_has_permission">has_permission</a>&lt;<a href="../groups/permissions_group.md#groups_permissions_group_MemberRemover">MemberRemover</a>&gt;(ctx.sender()), <a href="../groups/permissions_group.md#groups_permissions_group_ENotPermitted">ENotPermitted</a>);
    // <b>assert</b> member's permissions <b>entry</b> exists
    <b>assert</b>!(self.<a href="../groups/permissions_group.md#groups_permissions_group_is_member">is_member</a>(member), <a href="../groups/permissions_group.md#groups_permissions_group_EMemberNotFound">EMemberNotFound</a>);
    <b>let</b> member_permissions_set = self.permissions.borrow(member);
    // <b>assert</b> <b>if</b> member <b>has</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a> permission, there is at least one remaining after
    // removal
    <b>if</b> (member_permissions_set.contains(&type_name::with_defining_ids&lt;<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a>&gt;())) {
        <b>assert</b>!(self.managers_count &gt; 1, <a href="../groups/permissions_group.md#groups_permissions_group_ELastPermissionsManager">ELastPermissionsManager</a>);
        self.managers_count = self.managers_count - 1;
    };
    self.permissions.remove(member);
}
</code></pre>



</details>

<a name="groups_permissions_group_leave"></a>

## Function `leave`

I would argue yes. Not sure if we want to issue some sort
of LeftTicket?
Let's see if we go with a MemberCap approach later on,
in which case we would want the user that leaves, to be able
to burn their MemberCap for the rebate.
Allows the calling member to leave the PermissionsGroup.


<a name="@Parameters_6"></a>

### Parameters

- <code>self</code>: Mutable reference to the <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a></code> state.
- <code>ctx</code>: Transaction context for permission checks.

<a name="@Aborts_7"></a>

### Aborts

- If the member does not exist in the PermissionsGroup.
- If the member has <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a></code> permission and leaving would leave no
<code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a></code> remaining.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_leave">leave</a>(self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">groups::permissions_group::PermissionsGroup</a>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_leave">leave</a>(self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a>, ctx: &TxContext) {
    <b>let</b> member = ctx.sender();
    // <b>assert</b> member's permissions <b>entry</b> exists
    <b>assert</b>!(self.<a href="../groups/permissions_group.md#groups_permissions_group_is_member">is_member</a>(member), <a href="../groups/permissions_group.md#groups_permissions_group_EMemberNotFound">EMemberNotFound</a>);
    <b>let</b> member_permissions_set = self.permissions.borrow(member);
    // <b>assert</b> <b>if</b> member <b>has</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a> permission, there is at least one remaining after
    // removal
    <b>if</b> (member_permissions_set.contains(&type_name::with_defining_ids&lt;<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a>&gt;())) {
        <b>assert</b>!(self.managers_count &gt; 1, <a href="../groups/permissions_group.md#groups_permissions_group_ELastPermissionsManager">ELastPermissionsManager</a>);
        self.managers_count = self.managers_count - 1;
    };
    self.permissions.remove(member);
}
</code></pre>



</details>

<a name="groups_permissions_group_grant_permission"></a>

## Function `grant_permission`

Grants a new permission to an existing member.


<a name="@Type_Parameters_8"></a>

### Type Parameters

- <code>NewPermission</code>: The permission type to be granted to the member.

<a name="@Parameters_9"></a>

### Parameters

- <code>self</code>: Mutable reference to the <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a></code> state.
- <code>member</code>: Address of the member to whom the permission will be granted.
- <code>ctx</code>: Transaction context for permission checks.

<a name="@Aborts_10"></a>

### Aborts

- If the caller does not have <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a></code> permission.
- If the member does not exist in the PermissionsGroup.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_grant_permission">grant_permission</a>&lt;NewPermission: drop&gt;(self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">groups::permissions_group::PermissionsGroup</a>, member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_grant_permission">grant_permission</a>&lt;NewPermission: drop&gt;(
    self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a>,
    member: <b>address</b>,
    ctx: &TxContext,
) {
    // <b>assert</b> caller <b>has</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a> permission
    <b>assert</b>!(self.<a href="../groups/permissions_group.md#groups_permissions_group_has_permission">has_permission</a>&lt;<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a>&gt;(ctx.sender()), <a href="../groups/permissions_group.md#groups_permissions_group_ENotPermitted">ENotPermitted</a>);
    // <b>assert</b> member's permissions <b>entry</b> exists
    <b>assert</b>!(self.<a href="../groups/permissions_group.md#groups_permissions_group_is_member">is_member</a>(member), <a href="../groups/permissions_group.md#groups_permissions_group_EMemberNotFound">EMemberNotFound</a>);
    <b>let</b> member_permissions_set = self.permissions.borrow_mut(member);
    member_permissions_set.insert(type_name::with_defining_ids&lt;NewPermission&gt;());
    // <b>if</b> NewPermission is <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a>, increment count
    <b>if</b> (
        type_name::with_defining_ids&lt;NewPermission&gt;() == type_name::with_defining_ids&lt;<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a>&gt;()
    ) {
        self.managers_count = self.managers_count + 1;
    };
}
</code></pre>



</details>

<a name="groups_permissions_group_revoke_permission"></a>

## Function `revoke_permission`

Revokes an existing permission from a member.


<a name="@Type_Parameters_11"></a>

### Type Parameters

- <code>ExistingPermission</code>: The permission type to be revoked from the member.

<a name="@Parameters_12"></a>

### Parameters

- <code>self</code>: Mutable reference to the <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a></code> state.
- <code>member</code>: Address of the member from whom the permission will be revoked.
- <code>ctx</code>: Transaction context for permission checks.

<a name="@Aborts_13"></a>

### Aborts

- If the caller does not have <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a></code> permission.
- If the member does not exist in the permissions table.
- If revoking the permission would leave no <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a></code> remaining.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_revoke_permission">revoke_permission</a>&lt;ExistingPermission: drop&gt;(self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">groups::permissions_group::PermissionsGroup</a>, member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_revoke_permission">revoke_permission</a>&lt;ExistingPermission: drop&gt;(
    self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a>,
    member: <b>address</b>,
    ctx: &TxContext,
) {
    // <b>assert</b> caller <b>has</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a> permission
    <b>assert</b>!(self.<a href="../groups/permissions_group.md#groups_permissions_group_has_permission">has_permission</a>&lt;<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a>&gt;(ctx.sender()), <a href="../groups/permissions_group.md#groups_permissions_group_ENotPermitted">ENotPermitted</a>);
    // <b>assert</b> member's permissions <b>entry</b> exists
    <b>assert</b>!(self.permissions.contains(member), <a href="../groups/permissions_group.md#groups_permissions_group_EMemberNotFound">EMemberNotFound</a>);
    // <b>assert</b> after revocation, there is at least one <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a> remaining
    <b>if</b> (
        type_name::with_defining_ids&lt;ExistingPermission&gt;() == type_name::with_defining_ids&lt;<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsManager">PermissionsManager</a>&gt;()
    ) {
        <b>assert</b>!(self.managers_count &gt; 1, <a href="../groups/permissions_group.md#groups_permissions_group_ELastPermissionsManager">ELastPermissionsManager</a>);
        self.managers_count = self.managers_count - 1;
    };
    <b>let</b> member_permissions_set = self.permissions.borrow_mut(member);
    member_permissions_set.remove(&type_name::with_defining_ids&lt;ExistingPermission&gt;());
    // If the member <b>has</b> no more permissions, remove their <b>entry</b> from the table
    <b>if</b> (member_permissions_set.is_empty()) {
        self.permissions.remove(member);
    };
}
</code></pre>



</details>

<a name="groups_permissions_group_has_permission"></a>

## Function `has_permission`

Checks if the given address has the specified permission.

<a name="@Type_Parameters_14"></a>

### Type Parameters

- <code>Permission</code>: The permission type to check for.

<a name="@Parameters_15"></a>

### Parameters

- <code>self</code>: Reference to the <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a></code> state.
- <code>member</code>: Member address to check for the specified permission.

<a name="@Returns_16"></a>

### Returns

- <code>bool</code>: <code><b>true</b></code> if the address has the permission, <code><b>false</b></code> otherwise


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_has_permission">has_permission</a>&lt;Permission: drop&gt;(self: &<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">groups::permissions_group::PermissionsGroup</a>, member: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_has_permission">has_permission</a>&lt;Permission: drop&gt;(self: &<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a>, member: <b>address</b>): bool {
    self.permissions.borrow(member).contains(&type_name::with_defining_ids&lt;Permission&gt;())
}
</code></pre>



</details>

<a name="groups_permissions_group_is_member"></a>

## Function `is_member`

Checks if the given address is a member of the PermissionsGroup.


<a name="@Parameters_17"></a>

### Parameters

- <code>self</code>: Reference to the <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a></code> state.
- <code>member</code>: Address to check for membership.

<a name="@Returns_18"></a>

### Returns

- <code>bool</code>: <code><b>true</b></code> if the address is a member, <code><b>false</b></code> otherwise


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_is_member">is_member</a>(self: &<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">groups::permissions_group::PermissionsGroup</a>, member: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_is_member">is_member</a>(self: &<a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a>, member: <b>address</b>): bool {
    self.permissions.contains(member)
}
</code></pre>



</details>

<a name="groups_permissions_group_add_member_with_approval"></a>

## Function `add_member_with_approval`

Adds a new member using a JoinApproval from the join_policy module.
This is the safe way to add members via JoinPolicy - the approval proves
that all policy rules were satisfied.


<a name="@Type_Parameters_19"></a>

### Type Parameters

- <code>T</code>: The policy's witness type


<a name="@Parameters_20"></a>

### Parameters

- <code>self</code>: Mutable reference to the <code><a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a></code> state.
- <code>approval</code>: The JoinApproval proving the policy was satisfied (consumed).


<a name="@Aborts_21"></a>

### Aborts

- If the member is already in the group.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_add_member_with_approval">add_member_with_approval</a>&lt;T&gt;(self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">groups::permissions_group::PermissionsGroup</a>, approval: <a href="../groups/join_policy.md#groups_join_policy_JoinApproval">groups::join_policy::JoinApproval</a>&lt;T&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/permissions_group.md#groups_permissions_group_add_member_with_approval">add_member_with_approval</a>&lt;T&gt;(
    self: &<b>mut</b> <a href="../groups/permissions_group.md#groups_permissions_group_PermissionsGroup">PermissionsGroup</a>,
    approval: <a href="../groups/join_policy.md#groups_join_policy_JoinApproval">join_policy::JoinApproval</a>&lt;T&gt;,
) {
    <b>let</b> new_member = <a href="../groups/join_policy.md#groups_join_policy_consume_approval">join_policy::consume_approval</a>(approval);
    // <b>assert</b> new_member is not already present
    <b>assert</b>!(!self.<a href="../groups/permissions_group.md#groups_permissions_group_is_member">is_member</a>(new_member), <a href="../groups/permissions_group.md#groups_permissions_group_EMemberNotFound">EMemberNotFound</a>);
    // Add member with empty permissions set
    self.permissions.add(new_member, vec_set::empty&lt;TypeName&gt;());
}
</code></pre>



</details>
