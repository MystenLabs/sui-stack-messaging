/// Module: join_policy
///
/// Implements customizable join policies using the hot potato pattern.
/// This is modeled after Sui's TransferPolicy for maximum flexibility.
///
/// ## Overview
///
/// JoinPolicy allows group creators to define custom rules that users must satisfy
/// to join a group. Rules are implemented by third-party contracts and validated
/// via a receipt mechanism.
///
/// ## Pattern
///
/// 1. Group creator creates a JoinPolicy<T> with rules
/// 2. User calls `new_join_request()` → receives hot potato JoinRequest<T>
/// 3. User satisfies rules (each rule module calls `add_receipt()`)
/// 4. User calls `confirm_request()` → validates receipts, returns JoinApproval<T>
/// 5. Group module calls `consume_approval()` to get member address and add them
///
/// The hot potato pattern ensures all rules are satisfied in a single transaction.
/// The JoinApproval pattern allows any group type to integrate with JoinPolicy.
///
/// ## Type Parameter
///
/// The phantom type `T` ties a policy to a specific app/witness type, preventing
/// cross-app policy confusion. Each app defines its own witness struct.
///
/// ## Example Custom Rule
///
/// ```move
/// module my_app::payment_rule;
///
/// use groups::join_policy::{Self, JoinPolicy, JoinRequest};
///
/// public struct PaymentRule has drop {}
///
/// public struct PaymentConfig has store, drop {
///     fee: u64,
/// }
///
/// public fun satisfy<T>(
///     request: &mut JoinRequest<T>,
///     policy: &JoinPolicy<T>,
///     payment: Coin<SUI>,
/// ) {
///     let config: &PaymentConfig = join_policy::get_rule_config<T, PaymentRule,
/// PaymentConfig>(policy);
///     assert!(payment.value() >= config.fee, EInsufficientPayment);
///     // ... handle payment ...
///     join_policy::add_receipt<T, PaymentRule>(request, PaymentRule {});
/// }
/// ```
///
module groups::join_policy;

use std::type_name::{Self, TypeName};
use sui::bag::{Self, Bag};
use sui::package::Publisher;
use sui::vec_set::{Self, VecSet};

// === Error Codes ===

const EPolicyMismatch: u64 = 0;
const ERuleAlreadyExists: u64 = 1;
const EInvalidCap: u64 = 2;
const EMissingReceipts: u64 = 3;
const ENotOwner: u64 = 4;

// === Structs ===

/// A join request - hot potato that must be resolved by `confirm_request`.
/// Cannot be stored, dropped, or copied - must be consumed in the same transaction.
public struct JoinRequest<phantom T> {
    /// The policy this request is for
    policy_id: ID,
    /// Address of the user requesting to join
    member: address,
    /// Accumulated receipts proving rules have been satisfied
    receipts: VecSet<TypeName>,
}

/// Policy defining which rules must be satisfied to join a group.
/// The phantom type T ties this policy to a specific app.
public struct JoinPolicy<phantom T> has key, store {
    id: UID,
    /// Set of rule types that must be satisfied
    rules: VecSet<TypeName>,
    /// Rule configurations stored by rule type name
    rule_configs: Bag,
}

/// Capability to modify a JoinPolicy.
/// Transferred to the policy creator.
public struct JoinPolicyCap<phantom T> has key, store {
    id: UID,
    /// The policy this cap controls
    policy_id: ID,
}

/// A join approval - hot potato proving that all policy rules were satisfied.
/// Must be consumed by the group module to add the member.
/// This pattern allows any group type to integrate with JoinPolicy.
public struct JoinApproval<phantom T> {
    /// The policy that approved this join
    policy_id: ID,
    /// Address of the user approved to join
    member: address,
}

// === Policy Management ===

/// Creates a new JoinPolicy with no rules.
/// Requires a Publisher to prove ownership of type T.
/// The creator receives a JoinPolicyCap to add rules.
///
/// # Type Parameters
/// - `T`: Witness type tying this policy to a specific app
///
/// # Parameters
/// - `publisher`: Publisher proving ownership of type T
/// - `ctx`: Transaction context
///
/// # Returns
/// - `JoinPolicy<T>`: The new policy (should typically be shared)
/// - `JoinPolicyCap<T>`: Capability to modify the policy
///
/// # Aborts
/// - If publisher doesn't own type T
public fun new<T>(publisher: &Publisher, ctx: &mut TxContext): (JoinPolicy<T>, JoinPolicyCap<T>) {
    assert!(publisher.from_package<T>(), ENotOwner);

    let policy = JoinPolicy<T> {
        id: object::new(ctx),
        rules: vec_set::empty(),
        rule_configs: bag::new(ctx),
    };

    let cap = JoinPolicyCap<T> {
        id: object::new(ctx),
        policy_id: object::id(&policy),
    };

    (policy, cap)
}

/// Creates a new JoinPolicy and shares it.
/// Convenience function for simpler setup.
#[allow(lint(share_owned))]
public fun new_and_share<T>(publisher: &Publisher, ctx: &mut TxContext): JoinPolicyCap<T> {
    let (policy, cap) = new<T>(publisher, ctx);
    transfer::share_object(policy);
    cap
}

/// Adds a rule to the policy.
/// Rules are identified by their type and can have associated configuration.
///
/// # Type Parameters
/// - `T`: The policy's witness type
/// - `Rule`: The rule witness type (must have `drop`)
/// - `Config`: Configuration type for this rule (must have `store + drop`)
///
/// # Aborts
/// - If cap doesn't match the policy
/// - If rule already exists
public fun add_rule<T, Rule: drop, Config: store + drop>(
    policy: &mut JoinPolicy<T>,
    cap: &JoinPolicyCap<T>,
    config: Config,
) {
    assert!(object::id(policy) == cap.policy_id, EInvalidCap);

    let rule_type = type_name::with_defining_ids<Rule>();
    assert!(!policy.rules.contains(&rule_type), ERuleAlreadyExists);

    policy.rules.insert(rule_type);
    policy.rule_configs.add(rule_type, config);
}

/// Removes a rule from the policy.
///
/// # Type Parameters
/// - `T`: The policy's witness type
/// - `Rule`: The rule to remove
/// - `Config`: The config type to return
///
/// # Returns
/// - The rule's configuration
public fun remove_rule<T, Rule: drop, Config: store + drop>(
    policy: &mut JoinPolicy<T>,
    cap: &JoinPolicyCap<T>,
): Config {
    assert!(object::id(policy) == cap.policy_id, EInvalidCap);

    let rule_type = type_name::with_defining_ids<Rule>();
    policy.rules.remove(&rule_type);
    policy.rule_configs.remove(rule_type)
}

/// Gets the configuration for a rule.
/// Used by rule modules to access their config during validation.
public fun get_rule_config<T, Rule: drop, Config: store + drop>(policy: &JoinPolicy<T>): &Config {
    policy.rule_configs.borrow(type_name::with_defining_ids<Rule>())
}

// === Join Request Flow ===

/// Creates a new join request.
/// Returns a hot potato that must be resolved by `confirm_request`.
///
/// # Parameters
/// - `policy`: The policy to join under
/// - `ctx`: Transaction context (sender becomes the member)
///
/// # Returns
/// - `JoinRequest<T>`: Hot potato that must be consumed
public fun new_join_request<T>(policy: &JoinPolicy<T>, ctx: &TxContext): JoinRequest<T> {
    JoinRequest<T> {
        policy_id: object::id(policy),
        member: ctx.sender(),
        receipts: vec_set::empty(),
    }
}

/// Adds a receipt to the join request.
/// Called by rule modules after validating their conditions.
///
/// # Type Parameters
/// - `T`: The policy's witness type
/// - `Rule`: The rule being satisfied (must match a rule in the policy)
///
/// # Parameters
/// - `request`: The join request to add receipt to
/// - `_witness`: The rule witness (proves the rule module authorized this)
public fun add_receipt<T, Rule: drop>(request: &mut JoinRequest<T>, _witness: Rule) {
    request.receipts.insert(type_name::with_defining_ids<Rule>());
}

/// Confirms the join request and returns a JoinApproval.
/// Validates that all required receipts are present.
/// The approval must be consumed by the group module to add the member.
///
/// # Parameters
/// - `policy`: The JoinPolicy that was used
/// - `request`: The completed JoinRequest (consumed)
///
/// # Returns
/// - `JoinApproval<T>`: Hot potato that must be consumed to add the member
///
/// # Aborts
/// - If request's policy_id doesn't match policy
/// - If not all required receipts are present
public fun confirm_request<T>(
    policy: &JoinPolicy<T>,
    request: JoinRequest<T>,
): JoinApproval<T> {
    let JoinRequest { policy_id, member, receipts } = request;

    // Verify request is for this policy
    assert!(policy_id == object::id(policy), EPolicyMismatch);

    // Verify all rules have receipts
    assert!(receipts.length() == policy.rules.length(), EMissingReceipts);

    // Verify each rule has a matching receipt
    let rules = policy.rules.keys();
    let mut i = 0;
    while (i < rules.length()) {
        assert!(receipts.contains(&rules[i]), EMissingReceipts);
        i = i + 1;
    };

    // Return approval for the group module to consume
    JoinApproval<T> {
        policy_id,
        member,
    }
}

/// Consumes a JoinApproval and returns the member address.
/// This is package-internal to ensure only group implementations within
/// the groups package can consume approvals (enforcing the add_member_with_approval pattern).
///
/// # Parameters
/// - `approval`: The JoinApproval to consume
///
/// # Returns
/// - The address of the member who was approved to join
public(package) fun consume_approval<T>(approval: JoinApproval<T>): address {
    let JoinApproval { policy_id: _, member } = approval;
    member
}

// === Getters ===

/// Returns the policy ID this request is for.
public fun request_policy_id<T>(request: &JoinRequest<T>): ID {
    request.policy_id
}

/// Returns the member address in this request.
public fun request_member<T>(request: &JoinRequest<T>): address {
    request.member
}

/// Returns true if the policy has the specified rule.
public fun has_rule<T, Rule: drop>(policy: &JoinPolicy<T>): bool {
    policy.rules.contains(&type_name::with_defining_ids<Rule>())
}

/// Returns the number of rules in the policy.
public fun rules_count<T>(policy: &JoinPolicy<T>): u64 {
    policy.rules.length()
}

// === Test Helpers ===

#[test_only]
/// Creates a new JoinPolicy without Publisher verification.
/// Only for testing purposes.
public fun new_for_testing<T>(ctx: &mut TxContext): (JoinPolicy<T>, JoinPolicyCap<T>) {
    let policy = JoinPolicy<T> {
        id: object::new(ctx),
        rules: vec_set::empty(),
        rule_configs: bag::new(ctx),
    };

    let cap = JoinPolicyCap<T> {
        id: object::new(ctx),
        policy_id: object::id(&policy),
    };

    (policy, cap)
}

#[test_only]
public fun destroy_policy_for_testing<T>(policy: JoinPolicy<T>) {
    let JoinPolicy { id, rules: _, rule_configs } = policy;
    object::delete(id);
    bag::destroy_empty(rule_configs);
}

#[test_only]
public fun destroy_cap_for_testing<T>(cap: JoinPolicyCap<T>) {
    let JoinPolicyCap { id, policy_id: _ } = cap;
    object::delete(id);
}

// === Tests ===

#[test]
fun test_empty_policy_join() {
    let creator_ctx = &mut tx_context::dummy();

    let (policy, cap) = new_for_testing<TestWitness>(creator_ctx);

    // New user wants to join - use different sender
    let new_user = @0xCAFE;
    let user_ctx = &tx_context::new_from_hint(new_user, 0, 0, 0, 0);

    // Create join request (no rules to satisfy)
    let request = new_join_request(&policy, user_ctx);

    // Confirm request - should succeed with empty policy
    let approval = confirm_request(&policy, request);

    // Verify approval contains correct member
    let member = consume_approval(approval);
    assert!(member == new_user);

    // Cleanup
    destroy_policy_for_testing(policy);
    destroy_cap_for_testing(cap);
}

#[test]
fun test_policy_with_rule() {
    let creator_ctx = &mut tx_context::dummy();

    let (mut policy, cap) = new_for_testing<TestWitness>(creator_ctx);

    // Add a rule
    add_rule<TestWitness, TestRule, TestConfig>(&mut policy, &cap, TestConfig { value: 42 });

    // Verify rule was added
    assert!(has_rule<TestWitness, TestRule>(&policy));
    assert!(rules_count(&policy) == 1);

    // New user wants to join - use different sender
    let new_user = @0xCAFE;
    let user_ctx = &tx_context::new_from_hint(new_user, 0, 0, 0, 0);

    // Create join request
    let mut request = new_join_request(&policy, user_ctx);

    // Satisfy the rule
    add_receipt<TestWitness, TestRule>(&mut request, TestRule {});

    // Confirm request - returns approval
    let approval = confirm_request(&policy, request);

    // Verify approval contains correct member
    let member = consume_approval(approval);
    assert!(member == new_user);

    // Remove rule and cleanup
    let _config: TestConfig = remove_rule<TestWitness, TestRule, TestConfig>(&mut policy, &cap);

    destroy_policy_for_testing(policy);
    destroy_cap_for_testing(cap);
}

#[test]
#[expected_failure(abort_code = EMissingReceipts)]
fun test_missing_receipt_fails() {
    let creator_ctx = &mut tx_context::dummy();

    let (mut policy, cap) = new_for_testing<TestWitness>(creator_ctx);

    // Add a rule
    add_rule<TestWitness, TestRule, TestConfig>(&mut policy, &cap, TestConfig { value: 42 });

    // New user wants to join - use different sender
    let new_user = @0xCAFE;
    let user_ctx = &tx_context::new_from_hint(new_user, 0, 0, 0, 0);

    // Create join request but DON'T satisfy the rule
    let request = new_join_request(&policy, user_ctx);

    // This should fail - missing receipt
    let approval = confirm_request(&policy, request);

    // Cleanup (won't reach here)
    let _member = consume_approval(approval);
    let _config: TestConfig = remove_rule<TestWitness, TestRule, TestConfig>(&mut policy, &cap);
    destroy_policy_for_testing(policy);
    destroy_cap_for_testing(cap);
}

// Test types
#[test_only]
public struct TestWitness has drop {}

#[test_only]
public struct TestRule has drop {}

#[test_only]
public struct TestConfig has drop, store {
    value: u64,
}
