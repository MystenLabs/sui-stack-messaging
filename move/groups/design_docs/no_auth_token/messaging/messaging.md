
<a name="(messaging=0x0)_messaging"></a>

# Module `(messaging=0x0)::messaging`

Module: messaging

This module wraps the <code>permissions_group</code> library to provide messaging-specific
permission management. It defines messaging-specific permission types and delegates
to the underlying <code>PermissionsGroup</code> for core permission operations.


<a name="@Permission_Model_0"></a>

### Permission Model


Base permissions (from groups library, granted to creator automatically):
- <code>PermissionsManager</code>: Can grant/revoke any permissions
- <code>MemberAdder</code>: Can add new members (with no permissions)
- <code>MemberRemover</code>: Can remove members

Messaging-specific permissions (defined in this module):
- <code><a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingSender">MessagingSender</a></code>: Can send messages
- <code><a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingReader">MessagingReader</a></code>: Can read/decrypt messages
- <code><a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingDeleter">MessagingDeleter</a></code>: Can delete messages
- <code><a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingEditor">MessagingEditor</a></code>: Can edit messages


<a name="@Security_Model_1"></a>

### Security Model


- Adding a member (via <code><a href="../messaging/messaging.md#(messaging=0x0)_messaging_add_member">add_member</a></code>) only adds them to the roster with no permissions
- Granting permissions requires <code>PermissionsManager</code> permission
- This prevents privilege escalation where a <code>MemberAdder</code> could grant admin permissions


    -  [Permission Model](#@Permission_Model_0)
    -  [Security Model](#@Security_Model_1)
-  [Struct `MessagingSender`](#(messaging=0x0)_messaging_MessagingSender)
-  [Struct `MessagingReader`](#(messaging=0x0)_messaging_MessagingReader)
-  [Struct `MessagingDeleter`](#(messaging=0x0)_messaging_MessagingDeleter)
-  [Struct `MessagingEditor`](#(messaging=0x0)_messaging_MessagingEditor)
-  [Struct `MessagingGroup`](#(messaging=0x0)_messaging_MessagingGroup)
-  [Constants](#@Constants_2)
-  [Function `new`](#(messaging=0x0)_messaging_new)
-  [Function `new_with_encryption`](#(messaging=0x0)_messaging_new_with_encryption)
    -  [Parameters](#@Parameters_3)
    -  [Returns](#@Returns_4)
-  [Function `rotate_encryption_key`](#(messaging=0x0)_messaging_rotate_encryption_key)
    -  [Parameters](#@Parameters_5)
    -  [Aborts](#@Aborts_6)
-  [Function `current_encryption_key_version`](#(messaging=0x0)_messaging_current_encryption_key_version)
-  [Function `get_encrypted_key`](#(messaging=0x0)_messaging_get_encrypted_key)
    -  [Aborts](#@Aborts_7)
-  [Function `get_current_encrypted_key`](#(messaging=0x0)_messaging_get_current_encrypted_key)
    -  [Aborts](#@Aborts_8)
-  [Function `has_encryption`](#(messaging=0x0)_messaging_has_encryption)
-  [Function `add_member`](#(messaging=0x0)_messaging_add_member)
    -  [Aborts](#@Aborts_9)
-  [Function `remove_member`](#(messaging=0x0)_messaging_remove_member)
    -  [Aborts](#@Aborts_10)
-  [Function `leave`](#(messaging=0x0)_messaging_leave)
    -  [Aborts](#@Aborts_11)
-  [Function `grant_permission`](#(messaging=0x0)_messaging_grant_permission)
    -  [Type Parameters](#@Type_Parameters_12)
    -  [Aborts](#@Aborts_13)
-  [Function `revoke_permission`](#(messaging=0x0)_messaging_revoke_permission)
    -  [Type Parameters](#@Type_Parameters_14)
    -  [Aborts](#@Aborts_15)
-  [Function `is_authorized`](#(messaging=0x0)_messaging_is_authorized)
-  [Function `has_permission`](#(messaging=0x0)_messaging_has_permission)
-  [Function `is_member`](#(messaging=0x0)_messaging_is_member)
-  [Function `creator`](#(messaging=0x0)_messaging_creator)
-  [Function `add_member_with_approval`](#(messaging=0x0)_messaging_add_member_with_approval)
    -  [Type Parameters](#@Type_Parameters_16)
    -  [Parameters](#@Parameters_17)
    -  [Aborts](#@Aborts_18)


<pre><code><b>use</b> (groups=0x0)::join_policy;
<b>use</b> (groups=0x0)::permissions_group;
<b>use</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history">encryption_history</a>;
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
<b>use</b> <a href="../dependencies/sui/table_vec.md#sui_table_vec">sui::table_vec</a>;
<b>use</b> <a href="../dependencies/sui/transfer.md#sui_transfer">sui::transfer</a>;
<b>use</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context">sui::tx_context</a>;
<b>use</b> <a href="../dependencies/sui/types.md#sui_types">sui::types</a>;
<b>use</b> <a href="../dependencies/sui/vec_map.md#sui_vec_map">sui::vec_map</a>;
<b>use</b> <a href="../dependencies/sui/vec_set.md#sui_vec_set">sui::vec_set</a>;
</code></pre>



<a name="(messaging=0x0)_messaging_MessagingSender"></a>

## Struct `MessagingSender`

Permission to send messages to the group


<pre><code><b>public</b> <b>struct</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingSender">MessagingSender</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="(messaging=0x0)_messaging_MessagingReader"></a>

## Struct `MessagingReader`

Permission to read/decrypt messages from the group


<pre><code><b>public</b> <b>struct</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingReader">MessagingReader</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="(messaging=0x0)_messaging_MessagingDeleter"></a>

## Struct `MessagingDeleter`

Permission to delete messages in the group


<pre><code><b>public</b> <b>struct</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingDeleter">MessagingDeleter</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="(messaging=0x0)_messaging_MessagingEditor"></a>

## Struct `MessagingEditor`

Permission to edit messages in the group


<pre><code><b>public</b> <b>struct</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingEditor">MessagingEditor</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="(messaging=0x0)_messaging_MessagingGroup"></a>

## Struct `MessagingGroup`

A messaging group that wraps a PermissionsGroup with messaging-specific permissions.


<pre><code><b>public</b> <b>struct</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a> <b>has</b> key
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
<code>permissions_group: (groups=0x0)::permissions_group::PermissionsGroup</code>
</dt>
<dd>
</dd>
<dt>
<code><a href="../messaging/messaging.md#(messaging=0x0)_messaging_creator">creator</a>: <b>address</b></code>
</dt>
<dd>
 The address that created this group. Can be used as namespace for Seal encryption.
</dd>
</dl>


</details>

<a name="@Constants_2"></a>

## Constants


<a name="(messaging=0x0)_messaging_ENotPermitted"></a>



<pre><code><b>const</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_ENotPermitted">ENotPermitted</a>: u64 = 0;
</code></pre>



<a name="(messaging=0x0)_messaging_EEncryptionNotEnabled"></a>



<pre><code><b>const</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_EEncryptionNotEnabled">EEncryptionNotEnabled</a>: u64 = 1;
</code></pre>



<a name="(messaging=0x0)_messaging_new"></a>

## Function `new`

Creates a new MessagingGroup with the caller as the creator.
The creator is automatically granted all permissions:
- From groups library: PermissionsManager, MemberAdder, MemberRemover
- Messaging-specific: MessagingSender, MessagingReader, MessagingDeleter, MessagingEditor


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_new">new</a>(ctx: &<b>mut</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_new">new</a>(ctx: &<b>mut</b> TxContext): <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a> {
    <b>let</b> <b>mut</b> permissions_group = permissions_group::new(ctx);
    <b>let</b> group_creator = ctx.sender();
    // Grant <a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>-specific permissions to <a href="../messaging/messaging.md#(messaging=0x0)_messaging_creator">creator</a>
    permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingSender">MessagingSender</a>&gt;(group_creator, ctx);
    permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingReader">MessagingReader</a>&gt;(group_creator, ctx);
    permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingDeleter">MessagingDeleter</a>&gt;(group_creator, ctx);
    permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingEditor">MessagingEditor</a>&gt;(group_creator, ctx);
    <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a> {
        id: object::new(ctx),
        permissions_group,
        <a href="../messaging/messaging.md#(messaging=0x0)_messaging_creator">creator</a>: group_creator,
    }
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_new_with_encryption"></a>

## Function `new_with_encryption`

Creates a new MessagingGroup with encryption enabled.
The creator is automatically granted all permissions including EncryptionKeyRotator.


<a name="@Parameters_3"></a>

### Parameters

- <code>initial_encrypted_dek</code>: The initial encrypted DEK bytes (full EncryptedObject from Seal)
- <code>ctx</code>: Transaction context


<a name="@Returns_4"></a>

### Returns

- A new <code><a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a></code> with encryption history attached


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_new_with_encryption">new_with_encryption</a>(initial_encrypted_dek: vector&lt;u8&gt;, ctx: &<b>mut</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_new_with_encryption">new_with_encryption</a>(
    initial_encrypted_dek: vector&lt;u8&gt;,
    ctx: &<b>mut</b> TxContext,
): <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a> {
    <b>let</b> <b>mut</b> permissions_group = permissions_group::new(ctx);
    <b>let</b> group_creator = ctx.sender();
    // Grant <a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>-specific permissions to <a href="../messaging/messaging.md#(messaging=0x0)_messaging_creator">creator</a>
    permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingSender">MessagingSender</a>&gt;(group_creator, ctx);
    permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingReader">MessagingReader</a>&gt;(group_creator, ctx);
    permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingDeleter">MessagingDeleter</a>&gt;(group_creator, ctx);
    permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingEditor">MessagingEditor</a>&gt;(group_creator, ctx);
    // Grant encryption key rotation permission to <a href="../messaging/messaging.md#(messaging=0x0)_messaging_creator">creator</a>
    permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;EncryptionKeyRotator&gt;(group_creator, ctx);
    <b>let</b> <b>mut</b> group = <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a> {
        id: object::new(ctx),
        permissions_group,
        <a href="../messaging/messaging.md#(messaging=0x0)_messaging_creator">creator</a>: group_creator,
    };
    // Attach encryption history
    <b>let</b> history = <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_new">encryption_history::new</a>(initial_encrypted_dek, ctx);
    dynamic_field::add(&<b>mut</b> group.id, <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">encryption_history::key</a>(), history);
    group
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_rotate_encryption_key"></a>

## Function `rotate_encryption_key`

Rotates the encryption key for this MessagingGroup.
Requires the caller to have EncryptionKeyRotator permission.


<a name="@Parameters_5"></a>

### Parameters

- <code>self</code>: Mutable reference to the MessagingGroup
- <code>new_encrypted_dek</code>: The new encrypted DEK bytes (full EncryptedObject from Seal)
- <code>ctx</code>: Transaction context


<a name="@Aborts_6"></a>

### Aborts

- If caller doesn't have EncryptionKeyRotator permission
- If encryption is not enabled for this group


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_rotate_encryption_key">rotate_encryption_key</a>(self: &<b>mut</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, new_encrypted_dek: vector&lt;u8&gt;, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_rotate_encryption_key">rotate_encryption_key</a>(
    self: &<b>mut</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>,
    new_encrypted_dek: vector&lt;u8&gt;,
    ctx: &TxContext,
) {
    <b>assert</b>!(self.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_has_permission">has_permission</a>&lt;EncryptionKeyRotator&gt;(ctx.sender()), <a href="../messaging/messaging.md#(messaging=0x0)_messaging_ENotPermitted">ENotPermitted</a>);
    <b>assert</b>!(dynamic_field::exists_(&self.id, <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">encryption_history::key</a>()), <a href="../messaging/messaging.md#(messaging=0x0)_messaging_EEncryptionNotEnabled">EEncryptionNotEnabled</a>);
    <b>let</b> history: &<b>mut</b> EncryptionHistory = dynamic_field::borrow_mut(
        &<b>mut</b> self.id,
        <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">encryption_history::key</a>(),
    );
    history.rotate_key(new_encrypted_dek);
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_current_encryption_key_version"></a>

## Function `current_encryption_key_version`

Returns the current encryption key version.
Returns 0 if encryption is not enabled.


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_current_encryption_key_version">current_encryption_key_version</a>(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_current_encryption_key_version">current_encryption_key_version</a>(self: &<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>): u64 {
    <b>if</b> (!dynamic_field::exists_(&self.id, <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">encryption_history::key</a>())) {
        <b>return</b> 0
    };
    <b>let</b> history: &EncryptionHistory = dynamic_field::borrow(&self.id, <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">encryption_history::key</a>());
    history.current_key_version()
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_get_encrypted_key"></a>

## Function `get_encrypted_key`

Returns the encrypted DEK for a specific version.


<a name="@Aborts_7"></a>

### Aborts

- If encryption is not enabled
- If the key version doesn't exist


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_get_encrypted_key">get_encrypted_key</a>(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, version: u64): vector&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_get_encrypted_key">get_encrypted_key</a>(self: &<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>, version: u64): vector&lt;u8&gt; {
    <b>assert</b>!(dynamic_field::exists_(&self.id, <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">encryption_history::key</a>()), <a href="../messaging/messaging.md#(messaging=0x0)_messaging_EEncryptionNotEnabled">EEncryptionNotEnabled</a>);
    <b>let</b> history: &EncryptionHistory = dynamic_field::borrow(&self.id, <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">encryption_history::key</a>());
    history.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_get_encrypted_key">get_encrypted_key</a>(version)
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_get_current_encrypted_key"></a>

## Function `get_current_encrypted_key`

Returns the encrypted DEK for the current (latest) version.


<a name="@Aborts_8"></a>

### Aborts

- If encryption is not enabled


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_get_current_encrypted_key">get_current_encrypted_key</a>(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup): vector&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_get_current_encrypted_key">get_current_encrypted_key</a>(self: &<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>): vector&lt;u8&gt; {
    <b>assert</b>!(dynamic_field::exists_(&self.id, <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">encryption_history::key</a>()), <a href="../messaging/messaging.md#(messaging=0x0)_messaging_EEncryptionNotEnabled">EEncryptionNotEnabled</a>);
    <b>let</b> history: &EncryptionHistory = dynamic_field::borrow(&self.id, <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">encryption_history::key</a>());
    history.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_get_current_encrypted_key">get_current_encrypted_key</a>()
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_has_encryption"></a>

## Function `has_encryption`

Checks if encryption is enabled for this MessagingGroup.


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_has_encryption">has_encryption</a>(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_has_encryption">has_encryption</a>(self: &<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>): bool {
    dynamic_field::exists_(&self.id, <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">encryption_history::key</a>())
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_add_member"></a>

## Function `add_member`

Adds a new member with no initial permissions.
Requires the caller to have MemberAdder permission.
Use <code><a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a></code> afterward to assign permissions to the new member.


<a name="@Aborts_9"></a>

### Aborts

- If caller does not have MemberAdder permission
- If new_member is already a member


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_add_member">add_member</a>(self: &<b>mut</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, new_member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_add_member">add_member</a>(self: &<b>mut</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>, new_member: <b>address</b>, ctx: &TxContext) {
    self.permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_add_member">add_member</a>(new_member, ctx);
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_remove_member"></a>

## Function `remove_member`

Removes a member from the MessagingGroup.
Requires the caller to have MemberRemover permission.


<a name="@Aborts_10"></a>

### Aborts

- If caller does not have MemberRemover permission
- If member does not exist
- If removing the member would leave no PermissionsManager remaining


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_remove_member">remove_member</a>(self: &<b>mut</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_remove_member">remove_member</a>(self: &<b>mut</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>, member: <b>address</b>, ctx: &TxContext) {
    self.permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_remove_member">remove_member</a>(member, ctx);
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_leave"></a>

## Function `leave`

Allows the calling member to leave the MessagingGroup.


<a name="@Aborts_11"></a>

### Aborts

- If the caller is not a member
- If leaving would leave no PermissionsManager remaining


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_leave">leave</a>(self: &<b>mut</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_leave">leave</a>(self: &<b>mut</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>, ctx: &TxContext) {
    self.permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_leave">leave</a>(ctx);
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_grant_permission"></a>

## Function `grant_permission`

Grants a permission to an existing member.
Requires the caller to have PermissionsManager permission.


<a name="@Type_Parameters_12"></a>

### Type Parameters

- <code>Permission</code>: The permission type to grant


<a name="@Aborts_13"></a>

### Aborts

- If caller does not have PermissionsManager permission
- If member does not exist


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;Permission: drop&gt;(self: &<b>mut</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;Permission: drop&gt;(
    self: &<b>mut</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>,
    member: <b>address</b>,
    ctx: &TxContext,
) {
    self.permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_grant_permission">grant_permission</a>&lt;Permission&gt;(member, ctx);
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_revoke_permission"></a>

## Function `revoke_permission`

Revokes a permission from a member.
Requires the caller to have PermissionsManager permission.


<a name="@Type_Parameters_14"></a>

### Type Parameters

- <code>Permission</code>: The permission type to revoke


<a name="@Aborts_15"></a>

### Aborts

- If caller does not have PermissionsManager permission
- If member does not exist
- If revoking PermissionsManager would leave none remaining


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_revoke_permission">revoke_permission</a>&lt;Permission: drop&gt;(self: &<b>mut</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, member: <b>address</b>, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_revoke_permission">revoke_permission</a>&lt;Permission: drop&gt;(
    self: &<b>mut</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>,
    member: <b>address</b>,
    ctx: &TxContext,
) {
    self.permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_revoke_permission">revoke_permission</a>&lt;Permission&gt;(member, ctx);
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_is_authorized"></a>

## Function `is_authorized`

Checks if the caller has the specified permission.


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_is_authorized">is_authorized</a>&lt;Permission: drop&gt;(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_is_authorized">is_authorized</a>&lt;Permission: drop&gt;(self: &<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>, ctx: &TxContext): bool {
    self.permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_has_permission">has_permission</a>&lt;Permission&gt;(ctx.sender())
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_has_permission"></a>

## Function `has_permission`

Checks if an address has the specified permission.


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_has_permission">has_permission</a>&lt;Permission: drop&gt;(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, member: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_has_permission">has_permission</a>&lt;Permission: drop&gt;(self: &<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>, member: <b>address</b>): bool {
    self.permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_has_permission">has_permission</a>&lt;Permission&gt;(member)
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_is_member"></a>

## Function `is_member`

Checks if the given address is a member of the MessagingGroup.


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_is_member">is_member</a>(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, member: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_is_member">is_member</a>(self: &<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>, member: <b>address</b>): bool {
    self.permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_is_member">is_member</a>(member)
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_creator"></a>

## Function `creator`

Returns the creator address of this MessagingGroup.
Can be used as namespace for Seal encryption identity bytes.


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_creator">creator</a>(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_creator">creator</a>(self: &<a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>): <b>address</b> {
    self.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_creator">creator</a>
}
</code></pre>



</details>

<a name="(messaging=0x0)_messaging_add_member_with_approval"></a>

## Function `add_member_with_approval`

Adds a new member using a JoinApproval from the join_policy module.
This is the safe way to add members via JoinPolicy - the approval proves
that all policy rules were satisfied.


<a name="@Type_Parameters_16"></a>

### Type Parameters

- <code>T</code>: The policy's witness type


<a name="@Parameters_17"></a>

### Parameters

- <code>self</code>: Mutable reference to the <code><a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a></code> state.
- <code>approval</code>: The JoinApproval proving the policy was satisfied (consumed).


<a name="@Aborts_18"></a>

### Aborts

- If the member is already in the group.


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_add_member_with_approval">add_member_with_approval</a>&lt;T&gt;(self: &<b>mut</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, approval: (groups=0x0)::join_policy::JoinApproval&lt;T&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_add_member_with_approval">add_member_with_approval</a>&lt;T&gt;(
    self: &<b>mut</b> <a href="../messaging/messaging.md#(messaging=0x0)_messaging_MessagingGroup">MessagingGroup</a>,
    approval: join_policy::JoinApproval&lt;T&gt;,
) {
    self.permissions_group.<a href="../messaging/messaging.md#(messaging=0x0)_messaging_add_member_with_approval">add_member_with_approval</a>(approval);
}
</code></pre>



</details>
