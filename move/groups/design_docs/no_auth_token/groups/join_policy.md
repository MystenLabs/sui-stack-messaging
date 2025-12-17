
<a name="groups_join_policy"></a>

# Module `groups::join_policy`

Module: join_policy

Implements customizable join policies using the hot potato pattern.
This is modeled after Sui's TransferPolicy for maximum flexibility.


<a name="@Overview_0"></a>

### Overview


JoinPolicy allows group creators to define custom rules that users must satisfy
to join a group. Rules are implemented by third-party contracts and validated
via a receipt mechanism.


<a name="@Pattern_1"></a>

### Pattern


1. Group creator creates a JoinPolicy<T> with rules
2. User calls <code><a href="../groups/join_policy.md#groups_join_policy_new_join_request">new_join_request</a>()</code> → receives hot potato JoinRequest<T>
3. User satisfies rules (each rule module calls <code><a href="../groups/join_policy.md#groups_join_policy_add_receipt">add_receipt</a>()</code>)
4. User calls <code><a href="../groups/join_policy.md#groups_join_policy_confirm_request">confirm_request</a>()</code> → validates receipts, returns JoinApproval<T>
5. Group module calls <code><a href="../groups/join_policy.md#groups_join_policy_consume_approval">consume_approval</a>()</code> to get member address and add them

The hot potato pattern ensures all rules are satisfied in a single transaction.
The JoinApproval pattern allows any group type to integrate with JoinPolicy.


<a name="@Type_Parameter_2"></a>

### Type Parameter


The phantom type <code>T</code> ties a policy to a specific app/witness type, preventing
cross-app policy confusion. Each app defines its own witness struct.


<a name="@Example_Custom_Rule_3"></a>

### Example Custom Rule


```move
module my_app::payment_rule;

use groups::join_policy::{Self, JoinPolicy, JoinRequest};

public struct PaymentRule has drop {}

public struct PaymentConfig has store, drop {
fee: u64,
}

public fun satisfy<T>(
request: &mut JoinRequest<T>,
policy: &JoinPolicy<T>,
payment: Coin<SUI>,
) {
let config: &PaymentConfig = join_policy::get_rule_config<T, PaymentRule,
PaymentConfig>(policy);
assert!(payment.value() >= config.fee, EInsufficientPayment);
// ... handle payment ...
join_policy::add_receipt<T, PaymentRule>(request, PaymentRule {});
}
```


    -  [Overview](#@Overview_0)
    -  [Pattern](#@Pattern_1)
    -  [Type Parameter](#@Type_Parameter_2)
    -  [Example Custom Rule](#@Example_Custom_Rule_3)
-  [Struct `JoinRequest`](#groups_join_policy_JoinRequest)
-  [Struct `JoinPolicy`](#groups_join_policy_JoinPolicy)
-  [Struct `JoinPolicyCap`](#groups_join_policy_JoinPolicyCap)
-  [Struct `JoinApproval`](#groups_join_policy_JoinApproval)
-  [Constants](#@Constants_4)
-  [Function `new`](#groups_join_policy_new)
    -  [Type Parameters](#@Type_Parameters_5)
    -  [Parameters](#@Parameters_6)
    -  [Returns](#@Returns_7)
    -  [Aborts](#@Aborts_8)
-  [Function `new_and_share`](#groups_join_policy_new_and_share)
-  [Function `add_rule`](#groups_join_policy_add_rule)
    -  [Type Parameters](#@Type_Parameters_9)
    -  [Aborts](#@Aborts_10)
-  [Function `remove_rule`](#groups_join_policy_remove_rule)
    -  [Type Parameters](#@Type_Parameters_11)
    -  [Returns](#@Returns_12)
-  [Function `get_rule_config`](#groups_join_policy_get_rule_config)
-  [Function `new_join_request`](#groups_join_policy_new_join_request)
    -  [Parameters](#@Parameters_13)
    -  [Returns](#@Returns_14)
-  [Function `add_receipt`](#groups_join_policy_add_receipt)
    -  [Type Parameters](#@Type_Parameters_15)
    -  [Parameters](#@Parameters_16)
-  [Function `confirm_request`](#groups_join_policy_confirm_request)
    -  [Parameters](#@Parameters_17)
    -  [Returns](#@Returns_18)
    -  [Aborts](#@Aborts_19)
-  [Function `consume_approval`](#groups_join_policy_consume_approval)
    -  [Parameters](#@Parameters_20)
    -  [Returns](#@Returns_21)
-  [Function `request_policy_id`](#groups_join_policy_request_policy_id)
-  [Function `request_member`](#groups_join_policy_request_member)
-  [Function `has_rule`](#groups_join_policy_has_rule)
-  [Function `rules_count`](#groups_join_policy_rules_count)


<pre><code><b>use</b> <a href="../dependencies/std/address.md#std_address">std::address</a>;
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
<b>use</b> <a href="../dependencies/sui/transfer.md#sui_transfer">sui::transfer</a>;
<b>use</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context">sui::tx_context</a>;
<b>use</b> <a href="../dependencies/sui/types.md#sui_types">sui::types</a>;
<b>use</b> <a href="../dependencies/sui/vec_map.md#sui_vec_map">sui::vec_map</a>;
<b>use</b> <a href="../dependencies/sui/vec_set.md#sui_vec_set">sui::vec_set</a>;
</code></pre>



<a name="groups_join_policy_JoinRequest"></a>

## Struct `JoinRequest`

A join request - hot potato that must be resolved by <code><a href="../groups/join_policy.md#groups_join_policy_confirm_request">confirm_request</a></code>.
Cannot be stored, dropped, or copied - must be consumed in the same transaction.


<pre><code><b>public</b> <b>struct</b> <a href="../groups/join_policy.md#groups_join_policy_JoinRequest">JoinRequest</a>&lt;<b>phantom</b> T&gt;
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy_id: <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a></code>
</dt>
<dd>
 The policy this request is for
</dd>
<dt>
<code>member: <b>address</b></code>
</dt>
<dd>
 Address of the user requesting to join
</dd>
<dt>
<code>receipts: <a href="../dependencies/sui/vec_set.md#sui_vec_set_VecSet">sui::vec_set::VecSet</a>&lt;<a href="../dependencies/std/type_name.md#std_type_name_TypeName">std::type_name::TypeName</a>&gt;</code>
</dt>
<dd>
 Accumulated receipts proving rules have been satisfied
</dd>
</dl>


</details>

<a name="groups_join_policy_JoinPolicy"></a>

## Struct `JoinPolicy`

Policy defining which rules must be satisfied to join a group.
The phantom type T ties this policy to a specific app.


<pre><code><b>public</b> <b>struct</b> <a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;<b>phantom</b> T&gt; <b>has</b> key, store
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
<code>rules: <a href="../dependencies/sui/vec_set.md#sui_vec_set_VecSet">sui::vec_set::VecSet</a>&lt;<a href="../dependencies/std/type_name.md#std_type_name_TypeName">std::type_name::TypeName</a>&gt;</code>
</dt>
<dd>
 Set of rule types that must be satisfied
</dd>
<dt>
<code>rule_configs: <a href="../dependencies/sui/bag.md#sui_bag_Bag">sui::bag::Bag</a></code>
</dt>
<dd>
 Rule configurations stored by rule type name
</dd>
</dl>


</details>

<a name="groups_join_policy_JoinPolicyCap"></a>

## Struct `JoinPolicyCap`

Capability to modify a JoinPolicy.
Transferred to the policy creator.


<pre><code><b>public</b> <b>struct</b> <a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">JoinPolicyCap</a>&lt;<b>phantom</b> T&gt; <b>has</b> key, store
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
<code>policy_id: <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a></code>
</dt>
<dd>
 The policy this cap controls
</dd>
</dl>


</details>

<a name="groups_join_policy_JoinApproval"></a>

## Struct `JoinApproval`

A join approval - hot potato proving that all policy rules were satisfied.
Must be consumed by the group module to add the member.
This pattern allows any group type to integrate with JoinPolicy.


<pre><code><b>public</b> <b>struct</b> <a href="../groups/join_policy.md#groups_join_policy_JoinApproval">JoinApproval</a>&lt;<b>phantom</b> T&gt;
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy_id: <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a></code>
</dt>
<dd>
 The policy that approved this join
</dd>
<dt>
<code>member: <b>address</b></code>
</dt>
<dd>
 Address of the user approved to join
</dd>
</dl>


</details>

<a name="@Constants_4"></a>

## Constants


<a name="groups_join_policy_EPolicyMismatch"></a>



<pre><code><b>const</b> <a href="../groups/join_policy.md#groups_join_policy_EPolicyMismatch">EPolicyMismatch</a>: u64 = 0;
</code></pre>



<a name="groups_join_policy_ERuleAlreadyExists"></a>



<pre><code><b>const</b> <a href="../groups/join_policy.md#groups_join_policy_ERuleAlreadyExists">ERuleAlreadyExists</a>: u64 = 1;
</code></pre>



<a name="groups_join_policy_EInvalidCap"></a>



<pre><code><b>const</b> <a href="../groups/join_policy.md#groups_join_policy_EInvalidCap">EInvalidCap</a>: u64 = 2;
</code></pre>



<a name="groups_join_policy_EMissingReceipts"></a>



<pre><code><b>const</b> <a href="../groups/join_policy.md#groups_join_policy_EMissingReceipts">EMissingReceipts</a>: u64 = 3;
</code></pre>



<a name="groups_join_policy_ENotOwner"></a>



<pre><code><b>const</b> <a href="../groups/join_policy.md#groups_join_policy_ENotOwner">ENotOwner</a>: u64 = 4;
</code></pre>



<a name="groups_join_policy_new"></a>

## Function `new`

Creates a new JoinPolicy with no rules.
Requires a Publisher to prove ownership of type T.
The creator receives a JoinPolicyCap to add rules.


<a name="@Type_Parameters_5"></a>

### Type Parameters

- <code>T</code>: Witness type tying this policy to a specific app


<a name="@Parameters_6"></a>

### Parameters

- <code>publisher</code>: Publisher proving ownership of type T
- <code>ctx</code>: Transaction context


<a name="@Returns_7"></a>

### Returns

- <code><a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;T&gt;</code>: The new policy (should typically be shared)
- <code><a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">JoinPolicyCap</a>&lt;T&gt;</code>: Capability to modify the policy


<a name="@Aborts_8"></a>

### Aborts

- If publisher doesn't own type T


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_new">new</a>&lt;T&gt;(publisher: &<a href="../dependencies/sui/package.md#sui_package_Publisher">sui::package::Publisher</a>, ctx: &<b>mut</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): (<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">groups::join_policy::JoinPolicy</a>&lt;T&gt;, <a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">groups::join_policy::JoinPolicyCap</a>&lt;T&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_new">new</a>&lt;T&gt;(publisher: &Publisher, ctx: &<b>mut</b> TxContext): (<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;T&gt;, <a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">JoinPolicyCap</a>&lt;T&gt;) {
    <b>assert</b>!(publisher.from_package&lt;T&gt;(), <a href="../groups/join_policy.md#groups_join_policy_ENotOwner">ENotOwner</a>);
    <b>let</b> policy = <a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;T&gt; {
        id: object::new(ctx),
        rules: vec_set::empty(),
        rule_configs: bag::new(ctx),
    };
    <b>let</b> cap = <a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">JoinPolicyCap</a>&lt;T&gt; {
        id: object::new(ctx),
        policy_id: object::id(&policy),
    };
    (policy, cap)
}
</code></pre>



</details>

<a name="groups_join_policy_new_and_share"></a>

## Function `new_and_share`

Creates a new JoinPolicy and shares it.
Convenience function for simpler setup.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_new_and_share">new_and_share</a>&lt;T&gt;(publisher: &<a href="../dependencies/sui/package.md#sui_package_Publisher">sui::package::Publisher</a>, ctx: &<b>mut</b> <a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): <a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">groups::join_policy::JoinPolicyCap</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_new_and_share">new_and_share</a>&lt;T&gt;(publisher: &Publisher, ctx: &<b>mut</b> TxContext): <a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">JoinPolicyCap</a>&lt;T&gt; {
    <b>let</b> (policy, cap) = <a href="../groups/join_policy.md#groups_join_policy_new">new</a>&lt;T&gt;(publisher, ctx);
    transfer::share_object(policy);
    cap
}
</code></pre>



</details>

<a name="groups_join_policy_add_rule"></a>

## Function `add_rule`

Adds a rule to the policy.
Rules are identified by their type and can have associated configuration.


<a name="@Type_Parameters_9"></a>

### Type Parameters

- <code>T</code>: The policy's witness type
- <code>Rule</code>: The rule witness type (must have <code>drop</code>)
- <code>Config</code>: Configuration type for this rule (must have <code>store + drop</code>)


<a name="@Aborts_10"></a>

### Aborts

- If cap doesn't match the policy
- If rule already exists


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_add_rule">add_rule</a>&lt;T, Rule: drop, Config: drop, store&gt;(policy: &<b>mut</b> <a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">groups::join_policy::JoinPolicy</a>&lt;T&gt;, cap: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">groups::join_policy::JoinPolicyCap</a>&lt;T&gt;, config: Config)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_add_rule">add_rule</a>&lt;T, Rule: drop, Config: store + drop&gt;(
    policy: &<b>mut</b> <a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;T&gt;,
    cap: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">JoinPolicyCap</a>&lt;T&gt;,
    config: Config,
) {
    <b>assert</b>!(object::id(policy) == cap.policy_id, <a href="../groups/join_policy.md#groups_join_policy_EInvalidCap">EInvalidCap</a>);
    <b>let</b> rule_type = type_name::with_defining_ids&lt;Rule&gt;();
    <b>assert</b>!(!policy.rules.contains(&rule_type), <a href="../groups/join_policy.md#groups_join_policy_ERuleAlreadyExists">ERuleAlreadyExists</a>);
    policy.rules.insert(rule_type);
    policy.rule_configs.add(rule_type, config);
}
</code></pre>



</details>

<a name="groups_join_policy_remove_rule"></a>

## Function `remove_rule`

Removes a rule from the policy.


<a name="@Type_Parameters_11"></a>

### Type Parameters

- <code>T</code>: The policy's witness type
- <code>Rule</code>: The rule to remove
- <code>Config</code>: The config type to return


<a name="@Returns_12"></a>

### Returns

- The rule's configuration


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_remove_rule">remove_rule</a>&lt;T, Rule: drop, Config: drop, store&gt;(policy: &<b>mut</b> <a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">groups::join_policy::JoinPolicy</a>&lt;T&gt;, cap: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">groups::join_policy::JoinPolicyCap</a>&lt;T&gt;): Config
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_remove_rule">remove_rule</a>&lt;T, Rule: drop, Config: store + drop&gt;(
    policy: &<b>mut</b> <a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;T&gt;,
    cap: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicyCap">JoinPolicyCap</a>&lt;T&gt;,
): Config {
    <b>assert</b>!(object::id(policy) == cap.policy_id, <a href="../groups/join_policy.md#groups_join_policy_EInvalidCap">EInvalidCap</a>);
    <b>let</b> rule_type = type_name::with_defining_ids&lt;Rule&gt;();
    policy.rules.remove(&rule_type);
    policy.rule_configs.remove(rule_type)
}
</code></pre>



</details>

<a name="groups_join_policy_get_rule_config"></a>

## Function `get_rule_config`

Gets the configuration for a rule.
Used by rule modules to access their config during validation.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_get_rule_config">get_rule_config</a>&lt;T, Rule: drop, Config: drop, store&gt;(policy: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">groups::join_policy::JoinPolicy</a>&lt;T&gt;): &Config
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_get_rule_config">get_rule_config</a>&lt;T, Rule: drop, Config: store + drop&gt;(policy: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;T&gt;): &Config {
    policy.rule_configs.borrow(type_name::with_defining_ids&lt;Rule&gt;())
}
</code></pre>



</details>

<a name="groups_join_policy_new_join_request"></a>

## Function `new_join_request`

Creates a new join request.
Returns a hot potato that must be resolved by <code><a href="../groups/join_policy.md#groups_join_policy_confirm_request">confirm_request</a></code>.


<a name="@Parameters_13"></a>

### Parameters

- <code>policy</code>: The policy to join under
- <code>ctx</code>: Transaction context (sender becomes the member)


<a name="@Returns_14"></a>

### Returns

- <code><a href="../groups/join_policy.md#groups_join_policy_JoinRequest">JoinRequest</a>&lt;T&gt;</code>: Hot potato that must be consumed


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_new_join_request">new_join_request</a>&lt;T&gt;(policy: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">groups::join_policy::JoinPolicy</a>&lt;T&gt;, ctx: &<a href="../dependencies/sui/tx_context.md#sui_tx_context_TxContext">sui::tx_context::TxContext</a>): <a href="../groups/join_policy.md#groups_join_policy_JoinRequest">groups::join_policy::JoinRequest</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_new_join_request">new_join_request</a>&lt;T&gt;(policy: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;T&gt;, ctx: &TxContext): <a href="../groups/join_policy.md#groups_join_policy_JoinRequest">JoinRequest</a>&lt;T&gt; {
    <a href="../groups/join_policy.md#groups_join_policy_JoinRequest">JoinRequest</a>&lt;T&gt; {
        policy_id: object::id(policy),
        member: ctx.sender(),
        receipts: vec_set::empty(),
    }
}
</code></pre>



</details>

<a name="groups_join_policy_add_receipt"></a>

## Function `add_receipt`

Adds a receipt to the join request.
Called by rule modules after validating their conditions.


<a name="@Type_Parameters_15"></a>

### Type Parameters

- <code>T</code>: The policy's witness type
- <code>Rule</code>: The rule being satisfied (must match a rule in the policy)


<a name="@Parameters_16"></a>

### Parameters

- <code>request</code>: The join request to add receipt to
- <code>_witness</code>: The rule witness (proves the rule module authorized this)


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_add_receipt">add_receipt</a>&lt;T, Rule: drop&gt;(request: &<b>mut</b> <a href="../groups/join_policy.md#groups_join_policy_JoinRequest">groups::join_policy::JoinRequest</a>&lt;T&gt;, _witness: Rule)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_add_receipt">add_receipt</a>&lt;T, Rule: drop&gt;(request: &<b>mut</b> <a href="../groups/join_policy.md#groups_join_policy_JoinRequest">JoinRequest</a>&lt;T&gt;, _witness: Rule) {
    request.receipts.insert(type_name::with_defining_ids&lt;Rule&gt;());
}
</code></pre>



</details>

<a name="groups_join_policy_confirm_request"></a>

## Function `confirm_request`

Confirms the join request and returns a JoinApproval.
Validates that all required receipts are present.
The approval must be consumed by the group module to add the member.


<a name="@Parameters_17"></a>

### Parameters

- <code>policy</code>: The JoinPolicy that was used
- <code>request</code>: The completed JoinRequest (consumed)


<a name="@Returns_18"></a>

### Returns

- <code><a href="../groups/join_policy.md#groups_join_policy_JoinApproval">JoinApproval</a>&lt;T&gt;</code>: Hot potato that must be consumed to add the member


<a name="@Aborts_19"></a>

### Aborts

- If request's policy_id doesn't match policy
- If not all required receipts are present


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_confirm_request">confirm_request</a>&lt;T&gt;(policy: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">groups::join_policy::JoinPolicy</a>&lt;T&gt;, request: <a href="../groups/join_policy.md#groups_join_policy_JoinRequest">groups::join_policy::JoinRequest</a>&lt;T&gt;): <a href="../groups/join_policy.md#groups_join_policy_JoinApproval">groups::join_policy::JoinApproval</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_confirm_request">confirm_request</a>&lt;T&gt;(
    policy: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;T&gt;,
    request: <a href="../groups/join_policy.md#groups_join_policy_JoinRequest">JoinRequest</a>&lt;T&gt;,
): <a href="../groups/join_policy.md#groups_join_policy_JoinApproval">JoinApproval</a>&lt;T&gt; {
    <b>let</b> <a href="../groups/join_policy.md#groups_join_policy_JoinRequest">JoinRequest</a> { policy_id, member, receipts } = request;
    // Verify request is <b>for</b> this policy
    <b>assert</b>!(policy_id == object::id(policy), <a href="../groups/join_policy.md#groups_join_policy_EPolicyMismatch">EPolicyMismatch</a>);
    // Verify all rules have receipts
    <b>assert</b>!(receipts.length() == policy.rules.length(), <a href="../groups/join_policy.md#groups_join_policy_EMissingReceipts">EMissingReceipts</a>);
    // Verify each rule <b>has</b> a matching receipt
    <b>let</b> rules = policy.rules.keys();
    <b>let</b> <b>mut</b> i = 0;
    <b>while</b> (i &lt; rules.length()) {
        <b>assert</b>!(receipts.contains(&rules[i]), <a href="../groups/join_policy.md#groups_join_policy_EMissingReceipts">EMissingReceipts</a>);
        i = i + 1;
    };
    // Return approval <b>for</b> the group <b>module</b> to consume
    <a href="../groups/join_policy.md#groups_join_policy_JoinApproval">JoinApproval</a>&lt;T&gt; {
        policy_id,
        member,
    }
}
</code></pre>



</details>

<a name="groups_join_policy_consume_approval"></a>

## Function `consume_approval`

Consumes a JoinApproval and returns the member address.
This is package-internal to ensure only group implementations within
the groups package can consume approvals (enforcing the add_member_with_approval pattern).


<a name="@Parameters_20"></a>

### Parameters

- <code>approval</code>: The JoinApproval to consume


<a name="@Returns_21"></a>

### Returns

- The address of the member who was approved to join


<pre><code><b>public</b>(package) <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_consume_approval">consume_approval</a>&lt;T&gt;(approval: <a href="../groups/join_policy.md#groups_join_policy_JoinApproval">groups::join_policy::JoinApproval</a>&lt;T&gt;): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(package) <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_consume_approval">consume_approval</a>&lt;T&gt;(approval: <a href="../groups/join_policy.md#groups_join_policy_JoinApproval">JoinApproval</a>&lt;T&gt;): <b>address</b> {
    <b>let</b> <a href="../groups/join_policy.md#groups_join_policy_JoinApproval">JoinApproval</a> { policy_id: _, member } = approval;
    member
}
</code></pre>



</details>

<a name="groups_join_policy_request_policy_id"></a>

## Function `request_policy_id`

Returns the policy ID this request is for.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_request_policy_id">request_policy_id</a>&lt;T&gt;(request: &<a href="../groups/join_policy.md#groups_join_policy_JoinRequest">groups::join_policy::JoinRequest</a>&lt;T&gt;): <a href="../dependencies/sui/object.md#sui_object_ID">sui::object::ID</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_request_policy_id">request_policy_id</a>&lt;T&gt;(request: &<a href="../groups/join_policy.md#groups_join_policy_JoinRequest">JoinRequest</a>&lt;T&gt;): ID {
    request.policy_id
}
</code></pre>



</details>

<a name="groups_join_policy_request_member"></a>

## Function `request_member`

Returns the member address in this request.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_request_member">request_member</a>&lt;T&gt;(request: &<a href="../groups/join_policy.md#groups_join_policy_JoinRequest">groups::join_policy::JoinRequest</a>&lt;T&gt;): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_request_member">request_member</a>&lt;T&gt;(request: &<a href="../groups/join_policy.md#groups_join_policy_JoinRequest">JoinRequest</a>&lt;T&gt;): <b>address</b> {
    request.member
}
</code></pre>



</details>

<a name="groups_join_policy_has_rule"></a>

## Function `has_rule`

Returns true if the policy has the specified rule.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_has_rule">has_rule</a>&lt;T, Rule: drop&gt;(policy: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">groups::join_policy::JoinPolicy</a>&lt;T&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_has_rule">has_rule</a>&lt;T, Rule: drop&gt;(policy: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;T&gt;): bool {
    policy.rules.contains(&type_name::with_defining_ids&lt;Rule&gt;())
}
</code></pre>



</details>

<a name="groups_join_policy_rules_count"></a>

## Function `rules_count`

Returns the number of rules in the policy.


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_rules_count">rules_count</a>&lt;T&gt;(policy: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">groups::join_policy::JoinPolicy</a>&lt;T&gt;): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="../groups/join_policy.md#groups_join_policy_rules_count">rules_count</a>&lt;T&gt;(policy: &<a href="../groups/join_policy.md#groups_join_policy_JoinPolicy">JoinPolicy</a>&lt;T&gt;): u64 {
    policy.rules.length()
}
</code></pre>



</details>
