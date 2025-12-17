
<a name="(messaging=0x0)_encryption_history"></a>

# Module `(messaging=0x0)::encryption_history`

Module: encryption_history

This module provides envelope encryption key management for MessagingGroup.
It stores encrypted DEKs (Data Encryption Keys) that have been encrypted with Seal,
supporting key rotation for security purposes.


<a name="@Design_0"></a>

### Design


- EncryptionHistory is attached to MessagingGroup via dynamic field
- Stores full EncryptedObject bytes from Seal (which contain the id/namespace)
- Supports key rotation with version tracking


<a name="@Usage_1"></a>

### Usage


Use <code>messaging::new_with_encryption</code> to create a MessagingGroup with encryption enabled.
Use <code>messaging::rotate_encryption_key</code> to rotate keys.


    -  [Design](#@Design_0)
    -  [Usage](#@Usage_1)
-  [Struct `EncryptionKeyRotator`](#(messaging=0x0)_encryption_history_EncryptionKeyRotator)
-  [Struct `EncryptionHistoryKey`](#(messaging=0x0)_encryption_history_EncryptionHistoryKey)
-  [Struct `EncryptionHistory`](#(messaging=0x0)_encryption_history_EncryptionHistory)
-  [Constants](#@Constants_2)
-  [Function `new`](#(messaging=0x0)_encryption_history_new)
    -  [Parameters](#@Parameters_3)
    -  [Returns](#@Returns_4)
-  [Function `rotate_key`](#(messaging=0x0)_encryption_history_rotate_key)
    -  [Parameters](#@Parameters_5)
-  [Function `current_key_version`](#(messaging=0x0)_encryption_history_current_key_version)
-  [Function `get_encrypted_key`](#(messaging=0x0)_encryption_history_get_encrypted_key)
    -  [Aborts](#@Aborts_6)
-  [Function `get_current_encrypted_key`](#(messaging=0x0)_encryption_history_get_current_encrypted_key)
-  [Function `key`](#(messaging=0x0)_encryption_history_key)


<pre><code><b>use</b> <a href="../dependencies/std/ascii.md#std_ascii">std::ascii</a>;
<b>use</b> <a href="../dependencies/std/bcs.md#std_bcs">std::bcs</a>;
<b>use</b> <a href="../dependencies/std/option.md#std_option">std::option</a>;
<b>use</b> <a href="../dependencies/std/string.md#std_string">std::string</a>;
<b>use</b> <a href="../dependencies/std/vector.md#std_vector">std::vector</a>;
<b>use</b> <a href="../dependencies/sui/address.md#sui_address">sui::address</a>;
<b>use</b> <a href="../dependencies/sui/dynamic_field.md#sui_dynamic_field">sui::dynamic_field</a>;
<b>use</b> <a href="../dependencies/sui/hex.md#sui_hex">sui::hex</a>;
<b>use</b> <a href="../dependencies/sui/object.md#sui_object">sui::object</a>;
<b>use</b> <a href="../dependencies/sui/table.md#sui_table">sui::table</a>;
<b>use</b> <a href="../dependencies/sui/table_vec.md#sui_table_vec">sui::table_vec</a>;
<b>use</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context">sui::tx_context</a>;
</code></pre>



<a name="(messaging=0x0)_encryption_history_EncryptionKeyRotator"></a>

## Struct `EncryptionKeyRotator`

Permission to rotate encryption keys.
Automatically granted to creator when using <code>new_with_encryption</code>.


<pre><code><b>public</b> <b>struct</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionKeyRotator">EncryptionKeyRotator</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="(messaging=0x0)_encryption_history_EncryptionHistoryKey"></a>

## Struct `EncryptionHistoryKey`

Key for the dynamic field attachment on MessagingGroup.


<pre><code><b>public</b> <b>struct</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistoryKey">EncryptionHistoryKey</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
</dl>


</details>

<a name="(messaging=0x0)_encryption_history_EncryptionHistory"></a>

## Struct `EncryptionHistory`

Stores encryption key history for a MessagingGroup.
Attached as a dynamic field on MessagingGroup.


<pre><code><b>public</b> <b>struct</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">EncryptionHistory</a> <b>has</b> store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>encrypted_keys: <a href="../dependencies/sui/table_vec.md#sui_table_vec_TableVec">sui::table_vec::TableVec</a>&lt;vector&lt;u8&gt;&gt;</code>
</dt>
<dd>
 Sequential storage of encrypted DEKs. Index = key version.
 Each entry is full EncryptedObject bytes from Seal
 (contains: version, packageId, id, services, threshold, encryptedShares, ciphertext)
</dd>
</dl>


</details>

<a name="@Constants_2"></a>

## Constants


<a name="(messaging=0x0)_encryption_history_EKeyVersionNotFound"></a>



<pre><code><b>const</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EKeyVersionNotFound">EKeyVersionNotFound</a>: u64 = 0;
</code></pre>



<a name="(messaging=0x0)_encryption_history_new"></a>

## Function `new`

Creates a new EncryptionHistory with an initial encrypted DEK.


<a name="@Parameters_3"></a>

### Parameters

- <code>initial_encrypted_dek</code>: The initial encrypted DEK bytes (full EncryptedObject from Seal)
- <code>ctx</code>: Transaction context


<a name="@Returns_4"></a>

### Returns

- A new <code><a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">EncryptionHistory</a></code> with version 0


<pre><code><b>public</b>(package) <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_new">new</a>(initial_encrypted_dek: vector&lt;u8&gt;, ctx: &<b>mut</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">encryption_history::EncryptionHistory</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(package) <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_new">new</a>(
    initial_encrypted_dek: vector&lt;u8&gt;,
    ctx: &<b>mut</b> TxContext,
): <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">EncryptionHistory</a> {
    <b>let</b> <b>mut</b> encrypted_keys = table_vec::empty&lt;vector&lt;u8&gt;&gt;(ctx);
    encrypted_keys.push_back(initial_encrypted_dek);
    <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">EncryptionHistory</a> {
        encrypted_keys,
    }
}
</code></pre>



</details>

<a name="(messaging=0x0)_encryption_history_rotate_key"></a>

## Function `rotate_key`

Rotates to a new encryption key.
Appends the new encrypted DEK (version = length - 1 after push).


<a name="@Parameters_5"></a>

### Parameters

- <code>self</code>: Mutable reference to the EncryptionHistory
- <code>new_encrypted_dek</code>: The new encrypted DEK bytes (full EncryptedObject from Seal)


<pre><code><b>public</b>(package) <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_rotate_key">rotate_key</a>(self: &<b>mut</b> (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">encryption_history::EncryptionHistory</a>, new_encrypted_dek: vector&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(package) <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_rotate_key">rotate_key</a>(
    self: &<b>mut</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">EncryptionHistory</a>,
    new_encrypted_dek: vector&lt;u8&gt;,
) {
    self.encrypted_keys.push_back(new_encrypted_dek);
}
</code></pre>



</details>

<a name="(messaging=0x0)_encryption_history_current_key_version"></a>

## Function `current_key_version`

Returns the current key version (0-indexed).


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_current_key_version">current_key_version</a>(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">encryption_history::EncryptionHistory</a>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_current_key_version">current_key_version</a>(self: &<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">EncryptionHistory</a>): u64 {
    self.encrypted_keys.length() - 1
}
</code></pre>



</details>

<a name="(messaging=0x0)_encryption_history_get_encrypted_key"></a>

## Function `get_encrypted_key`

Returns the encrypted DEK for a specific version.


<a name="@Aborts_6"></a>

### Aborts

- If the key version doesn't exist


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_get_encrypted_key">get_encrypted_key</a>(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">encryption_history::EncryptionHistory</a>, version: u64): vector&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_get_encrypted_key">get_encrypted_key</a>(self: &<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">EncryptionHistory</a>, version: u64): vector&lt;u8&gt; {
    <b>assert</b>!(version &lt; self.encrypted_keys.length(), <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EKeyVersionNotFound">EKeyVersionNotFound</a>);
    *self.encrypted_keys.borrow(version)
}
</code></pre>



</details>

<a name="(messaging=0x0)_encryption_history_get_current_encrypted_key"></a>

## Function `get_current_encrypted_key`

Returns the encrypted DEK for the current (latest) version.


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_get_current_encrypted_key">get_current_encrypted_key</a>(self: &(<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">encryption_history::EncryptionHistory</a>): vector&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_get_current_encrypted_key">get_current_encrypted_key</a>(self: &<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistory">EncryptionHistory</a>): vector&lt;u8&gt; {
    self.<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_get_encrypted_key">get_encrypted_key</a>(self.<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_current_key_version">current_key_version</a>())
}
</code></pre>



</details>

<a name="(messaging=0x0)_encryption_history_key"></a>

## Function `key`

Returns the dynamic field key for EncryptionHistory.
Used by the messaging module to access the encryption history.


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">key</a>(): (<a href="../messaging/messaging.md#(messaging=0x0)_messaging">messaging</a>=0x0)::<a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistoryKey">encryption_history::EncryptionHistoryKey</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_key">key</a>(): <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistoryKey">EncryptionHistoryKey</a> {
    <a href="../messaging/encryption_history.md#(messaging=0x0)_encryption_history_EncryptionHistoryKey">EncryptionHistoryKey</a> {}
}
</code></pre>



</details>
