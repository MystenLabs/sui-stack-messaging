
<a name="(messaging=0x0)_seal_policies"></a>

# Module `(messaging=0x0)::seal_policies`

Module: seal_policies

This module provides default <code>seal_approve</code> functions for Seal encryption access control.
These functions are called by Seal key servers (via dry-run) to determine if a user
should be able to decrypt encrypted content.


<a name="@Namespace_0"></a>

### Namespace


The default implementation uses the <code>creator</code> address as the namespace prefix.
This enables single-PTB group creation since the creator address is known before
the transaction executes.

Identity bytes format: [creator_address (32 bytes)][nonce (variable)]


<a name="@Custom_Implementations_1"></a>

### Custom Implementations


Third-party apps can implement their own <code>seal_approve</code> functions with custom logic:
- Subscription-based access
- Time-limited access
- NFT-gated access
- etc.

The custom <code>seal_approve</code> must be in the same package that was used during <code>seal.encrypt</code>.


    -  [Namespace](#@Namespace_0)
    -  [Custom Implementations](#@Custom_Implementations_1)
-  [Constants](#@Constants_2)
-  [Function `check_namespace`](#(messaging=0x0)_seal_policies_check_namespace)
-  [Function `seal_approve_member`](#(messaging=0x0)_seal_policies_seal_approve_member)
    -  [Parameters](#@Parameters_3)
    -  [Aborts](#@Aborts_4)
-  [Function `seal_approve_reader`](#(messaging=0x0)_seal_policies_seal_approve_reader)
    -  [Parameters](#@Parameters_5)
    -  [Aborts](#@Aborts_6)


<pre><code><b>use</b> (groups=0x0)::join_policy;
<b>use</b> (groups=0x0)::permissions_group;
<b>use</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history">encryption_history</a>;
<b>use</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>;
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



<a name="@Constants_2"></a>

## Constants


<a name="(messaging=0x0)_seal_policies_EInvalidNamespace"></a>



<pre><code><b>const</b> <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_EInvalidNamespace">EInvalidNamespace</a>: u64 = 0;
</code></pre>



<a name="(messaging=0x0)_seal_policies_ENotMember"></a>



<pre><code><b>const</b> <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_ENotMember">ENotMember</a>: u64 = 1;
</code></pre>



<a name="(messaging=0x0)_seal_policies_ENotPermitted"></a>



<pre><code><b>const</b> <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_ENotPermitted">ENotPermitted</a>: u64 = 2;
</code></pre>



<a name="(messaging=0x0)_seal_policies_check_namespace"></a>

## Function `check_namespace`

Validates that the id has the correct namespace prefix (creator address).
The creator address is used as the namespace to enable single-PTB group creation.


<pre><code><b>fun</b> <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_check_namespace">check_namespace</a>(group: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, id: &vector&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_check_namespace">check_namespace</a>(group: &MessagingGroup, id: &vector&lt;u8&gt;): bool {
    <b>let</b> namespace = group.creator().to_bytes();
    <b>let</b> namespace_len = namespace.length();
    <b>if</b> (namespace_len &gt; id.length()) {
        <b>return</b> <b>false</b>
    };
    <b>let</b> <b>mut</b> i = 0;
    <b>while</b> (i &lt; namespace_len) {
        <b>if</b> (namespace[i] != id[i]) {
            <b>return</b> <b>false</b>
        };
        i = i + 1;
    };
    <b>true</b>
}
</code></pre>



</details>

<a name="(messaging=0x0)_seal_policies_seal_approve_member"></a>

## Function `seal_approve_member`

Default seal_approve that checks membership.
Use this for simple "all members can decrypt" access control.


<a name="@Parameters_3"></a>

### Parameters

- <code>id</code>: The Seal identity bytes (should be [creator_address][nonce])
- <code>group</code>: Reference to the MessagingGroup
- <code>ctx</code>: Transaction context


<a name="@Aborts_4"></a>

### Aborts

- If id doesn't have correct namespace prefix (creator address)
- If caller is not a member


<pre><code><b>entry</b> <b>fun</b> <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_seal_approve_member">seal_approve_member</a>(id: vector&lt;u8&gt;, group: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>entry</b> <b>fun</b> <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_seal_approve_member">seal_approve_member</a>(
    id: vector&lt;u8&gt;,
    group: &MessagingGroup,
    ctx: &TxContext,
) {
    <b>assert</b>!(<a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_check_namespace">check_namespace</a>(group, &id), <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_EInvalidNamespace">EInvalidNamespace</a>);
    <b>assert</b>!(group.is_member(ctx.sender()), <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_ENotMember">ENotMember</a>);
}
</code></pre>



</details>

<a name="(messaging=0x0)_seal_policies_seal_approve_reader"></a>

## Function `seal_approve_reader`

Default seal_approve that checks MessagingReader permission.
Use this for granular "only readers can decrypt" access control.
This allows for temporary read bans while keeping membership.


<a name="@Parameters_5"></a>

### Parameters

- <code>id</code>: The Seal identity bytes (should be [creator_address][nonce])
- <code>group</code>: Reference to the MessagingGroup
- <code>ctx</code>: Transaction context


<a name="@Aborts_6"></a>

### Aborts

- If id doesn't have correct namespace prefix (creator address)
- If caller doesn't have MessagingReader permission


<pre><code><b>entry</b> <b>fun</b> <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_seal_approve_reader">seal_approve_reader</a>(id: vector&lt;u8&gt;, group: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::messaging::MessagingGroup, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>entry</b> <b>fun</b> <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_seal_approve_reader">seal_approve_reader</a>(
    id: vector&lt;u8&gt;,
    group: &MessagingGroup,
    ctx: &TxContext,
) {
    <b>assert</b>!(<a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_check_namespace">check_namespace</a>(group, &id), <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_EInvalidNamespace">EInvalidNamespace</a>);
    <b>assert</b>!(group.has_permission&lt;MessagingReader&gt;(ctx.sender()), <a href="../messaging/seal_policies.md#(messaging=0x0)_seal_policies_ENotPermitted">ENotPermitted</a>);
}
</code></pre>



</details>
