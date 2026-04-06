
<a name="sui_stack_messaging_group_leaver"></a>

# Module `sui_stack_messaging::group_leaver`

Module: group_leaver

Actor object that allows group members to leave a <code>PermissionedGroup&lt;T&gt;</code>.

<code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a></code> is a derived singleton object from <code>MessagingNamespace</code>.
It is granted <code>PermissionsAdmin</code> on every group created via <code><a href="../sui_stack_messaging/messaging.md#sui_stack_messaging_messaging_create_group">messaging::create_group</a></code>,
and exposes a <code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_leave">leave</a></code> function that calls <code>object_remove_member</code> on behalf of the caller.

This module does NOT import <code><a href="../sui_stack_messaging/messaging.md#sui_stack_messaging_messaging">messaging</a>.<b>move</b></code> to avoid a circular dependency.
The generic <code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_leave">leave</a>&lt;T: drop&gt;</code> is instantiated with the concrete <code>Messaging</code> type
at the call site in <code><a href="../sui_stack_messaging/messaging.md#sui_stack_messaging_messaging">messaging</a>.<b>move</b></code>.

All public entry points are in the <code><a href="../sui_stack_messaging/messaging.md#sui_stack_messaging_messaging">messaging</a></code> module:
- <code><a href="../sui_stack_messaging/messaging.md#sui_stack_messaging_messaging_leave">messaging::leave</a></code> - removes the caller from a group


-  [Struct `GroupLeaver`](#sui_stack_messaging_group_leaver_GroupLeaver)
-  [Constants](#@Constants_0)
-  [Function `new`](#sui_stack_messaging_group_leaver_new)
    -  [Parameters](#@Parameters_1)
    -  [Returns](#@Returns_2)
-  [Function `share`](#sui_stack_messaging_group_leaver_share)
-  [Function `derivation_key`](#sui_stack_messaging_group_leaver_derivation_key)
    -  [Returns](#@Returns_3)
-  [Function `leave`](#sui_stack_messaging_group_leaver_leave)
    -  [Aborts](#@Aborts_4)


<pre><code><b>use</b> <a href="../dependencies/std/address.md#std_address">std::address</a>;
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
<b>use</b> <a href="../dependencies/sui_groups/permissioned_group.md#sui_groups_permissioned_group">sui_groups::permissioned_group</a>;
<b>use</b> <a href="../dependencies/sui_groups/permissions_table.md#sui_groups_permissions_table">sui_groups::permissions_table</a>;
<b>use</b> <a href="../dependencies/sui_groups/unpause_cap.md#sui_groups_unpause_cap">sui_groups::unpause_cap</a>;
</code></pre>



<a name="sui_stack_messaging_group_leaver_GroupLeaver"></a>

## Struct `GroupLeaver`

Actor object that holds <code>PermissionsAdmin</code> on all messaging groups.
The <code>id</code> field is intentionally private — no UID getter is exposed.
All leave operations go through the package-internal <code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_leave">leave</a>&lt;T&gt;</code> function.


<pre><code><b>public</b> <b>struct</b> <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>id: <a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a></code>
</dt>
<dd>
</dd>
</dl>


</details>

<a name="@Constants_0"></a>

## Constants


<a name="sui_stack_messaging_group_leaver_GROUP_LEAVER_DERIVATION_KEY"></a>

Fixed derivation key for the singleton <code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a></code> derived from <code>MessagingNamespace</code>.


<pre><code><b>const</b> <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GROUP_LEAVER_DERIVATION_KEY">GROUP_LEAVER_DERIVATION_KEY</a>: vector&lt;u8&gt; = vector[103, 114, 111, 117, 112, 95, 108, 101, 97, 118, 101, 114];
</code></pre>



<a name="sui_stack_messaging_group_leaver_new"></a>

## Function `new`

Creates a new <code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a></code> derived from the namespace UID.
Called once during <code><a href="../sui_stack_messaging/messaging.md#sui_stack_messaging_messaging_init">messaging::init</a></code>.


<a name="@Parameters_1"></a>

### Parameters

- <code>namespace_uid</code>: Mutable reference to the <code>MessagingNamespace</code> UID


<a name="@Returns_2"></a>

### Returns

A new <code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a></code> object with a deterministic address.


<pre><code><b>public</b>(package) <b>fun</b> <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_new">new</a>(namespace_uid: &<b>mut</b> <a href="../dependencies/sui/object.md#sui_object_UID">sui::object::UID</a>): <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">sui_stack_messaging::group_leaver::GroupLeaver</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(package) <b>fun</b> <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_new">new</a>(namespace_uid: &<b>mut</b> UID): <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a> {
    <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a> {
        id: derived_object::claim(namespace_uid, <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GROUP_LEAVER_DERIVATION_KEY">GROUP_LEAVER_DERIVATION_KEY</a>.to_string()),
    }
}
</code></pre>



</details>

<a name="sui_stack_messaging_group_leaver_share"></a>

## Function `share`

Shares the <code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a></code> object on-chain.
Called once during <code><a href="../sui_stack_messaging/messaging.md#sui_stack_messaging_messaging_init">messaging::init</a></code> after creating the object.


<pre><code><b>public</b>(package) <b>fun</b> <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_share">share</a>(self: <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">sui_stack_messaging::group_leaver::GroupLeaver</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(package) <b>fun</b> <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_share">share</a>(self: <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a>) {
    transfer::share_object(self);
}
</code></pre>



</details>

<a name="sui_stack_messaging_group_leaver_derivation_key"></a>

## Function `derivation_key`

Returns the fixed derivation key string.
Used by <code><a href="../sui_stack_messaging/messaging.md#sui_stack_messaging_messaging_create_group">messaging::create_group</a></code> to compute the <code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a></code>'s address via
<code>derived_object::derive_address</code> without holding the object.


<a name="@Returns_3"></a>

### Returns

The string key used for address derivation.


<pre><code><b>public</b>(package) <b>fun</b> <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_derivation_key">derivation_key</a>(): <a href="../dependencies/std/string.md#std_string_String">std::string::String</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(package) <b>fun</b> <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_derivation_key">derivation_key</a>(): String {
    <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GROUP_LEAVER_DERIVATION_KEY">GROUP_LEAVER_DERIVATION_KEY</a>.to_string()
}
</code></pre>



</details>

<a name="sui_stack_messaging_group_leaver_leave"></a>

## Function `leave`

Removes the caller (<code>ctx.sender()</code>) from the group.
The <code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a></code> must have <code>PermissionsAdmin</code> on the group (granted at creation time).

Generic over <code>T: drop</code> so this module does not need to import <code><a href="../sui_stack_messaging/messaging.md#sui_stack_messaging_messaging">messaging</a>.<b>move</b></code>.
Instantiated as <code><a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_leave">leave</a>&lt;Messaging&gt;</code> at the call site in <code><a href="../sui_stack_messaging/messaging.md#sui_stack_messaging_messaging">messaging</a>.<b>move</b></code>.


<a name="@Aborts_4"></a>

### Aborts

- <code>ENotPermitted</code>: if this actor doesn't have <code>PermissionsAdmin</code> on the group
- <code>EMemberNotFound</code>: if the caller is not a member of the group
- <code>ELastPermissionsAdmin</code>: if the caller is the last <code>PermissionsAdmin</code>


<pre><code><b>public</b>(package) <b>fun</b> <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_leave">leave</a>&lt;T: drop&gt;(self: &<a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">sui_stack_messaging::group_leaver::GroupLeaver</a>, group: &<b>mut</b> <a href="../dependencies/sui_groups/permissioned_group.md#sui_groups_permissioned_group_PermissionedGroup">sui_groups::permissioned_group::PermissionedGroup</a>&lt;T&gt;, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(package) <b>fun</b> <a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_leave">leave</a>&lt;T: drop&gt;(
    self: &<a href="../sui_stack_messaging/group_leaver.md#sui_stack_messaging_group_leaver_GroupLeaver">GroupLeaver</a>,
    group: &<b>mut</b> PermissionedGroup&lt;T&gt;,
    ctx: &TxContext,
) {
    group.object_remove_member&lt;T&gt;(&self.id, ctx.sender());
}
</code></pre>



</details>
