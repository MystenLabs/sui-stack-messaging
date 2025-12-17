/// Module: paid_join_rule
///
/// Example custom JoinPolicy rule demonstrating payment-gated group membership.
/// This module showcases how third-party contracts can implement custom rules
/// for the `groups::join_policy` hot potato pattern, integrated with MessagingGroup.
///
/// ## Overview
///
/// This rule requires users to pay a fee to join a MessagingGroup. The fee and recipient
/// are configured when the rule is added to a JoinPolicy.
///
/// ## Pattern
///
/// Rules follow a standard pattern:
/// 1. Define a Rule witness type (has `drop` only)
/// 2. Define a Config type (has `store + drop`)
/// 3. Implement a `satisfy` function that validates and adds a receipt
///
/// ## Usage
///
/// ```move
/// // 1. Create MessagingGroup and JoinPolicy for your app
/// let group = messaging::new(ctx);
/// let (mut policy, cap) = join_policy::new<MyApp>(&publisher, ctx);
///
/// // 2. Add the payment rule
/// paid_join_rule::add_rule(&mut policy, &cap, 1_000_000_000, recipient_address); // 1 SUI fee
///
/// // 3. User joins by satisfying the rule
/// let mut request = join_policy::new_join_request(&policy, ctx);
/// paid_join_rule::satisfy(&mut request, &policy, payment_coin);
/// let approval = join_policy::confirm_request(&policy, request);
/// group.add_member_with_approval(approval);
/// ```
///
module app::paid_join_rule;

use groups::join_policy::{Self, JoinPolicy, JoinPolicyCap, JoinRequest};
use sui::coin::Coin;
use sui::sui::SUI;

// === Error Codes ===

const EInsufficientPayment: u64 = 0;

// === Structs ===

/// Rule witness type. Only has `drop` ability.
/// The existence of this type in a receipt proves the payment was made.
public struct PaymentRule has drop {}

/// Configuration for the payment rule.
/// Stored in the JoinPolicy's rule_configs Bag.
public struct PaymentConfig has store, drop {
    /// The fee required to join (in MIST)
    fee: u64,
    /// The address that receives the payment
    recipient: address,
}

// === Rule Management ===

/// Adds the payment rule to a JoinPolicy.
/// This is a convenience function that wraps `join_policy::add_rule`.
///
/// # Type Parameters
/// - `T`: The policy's witness type
///
/// # Parameters
/// - `policy`: The JoinPolicy to add the rule to
/// - `cap`: The capability proving ownership of the policy
/// - `fee`: The fee required to join (in MIST)
/// - `recipient`: The address that receives the payment
public fun add_rule<T>(
    policy: &mut JoinPolicy<T>,
    cap: &JoinPolicyCap<T>,
    fee: u64,
    recipient: address,
) {
    join_policy::add_rule<T, PaymentRule, PaymentConfig>(
        policy,
        cap,
        PaymentConfig { fee, recipient },
    );
}

/// Removes the payment rule from a JoinPolicy.
///
/// # Returns
/// - The PaymentConfig that was stored
public fun remove_rule<T>(
    policy: &mut JoinPolicy<T>,
    cap: &JoinPolicyCap<T>,
): PaymentConfig {
    join_policy::remove_rule<T, PaymentRule, PaymentConfig>(policy, cap)
}

// === Rule Satisfaction ===

/// Satisfies the payment rule by paying the required fee.
/// This function validates the payment and adds a receipt to the request.
///
/// # Type Parameters
/// - `T`: The policy's witness type
///
/// # Parameters
/// - `request`: The join request to add the receipt to
/// - `policy`: The JoinPolicy containing the rule configuration
/// - `payment`: SUI coin for payment (must be >= fee)
///
/// # Aborts
/// - If payment value is less than the configured fee
public fun satisfy<T>(
    request: &mut JoinRequest<T>,
    policy: &JoinPolicy<T>,
    payment: Coin<SUI>,
) {
    let config = join_policy::get_rule_config<T, PaymentRule, PaymentConfig>(policy);

    // Validate payment amount
    assert!(payment.value() >= config.fee, EInsufficientPayment);

    // Transfer payment to recipient
    transfer::public_transfer(payment, config.recipient);

    // Add receipt proving this rule was satisfied
    join_policy::add_receipt<T, PaymentRule>(request, PaymentRule {});
}

// === Getters ===

/// Returns the fee configured for a policy's payment rule.
public fun get_fee<T>(policy: &JoinPolicy<T>): u64 {
    let config = join_policy::get_rule_config<T, PaymentRule, PaymentConfig>(policy);
    config.fee
}

/// Returns the recipient configured for a policy's payment rule.
public fun get_recipient<T>(policy: &JoinPolicy<T>): address {
    let config = join_policy::get_rule_config<T, PaymentRule, PaymentConfig>(policy);
    config.recipient
}

// === Test Helpers ===

#[test_only]
public struct TestWitness has drop {}

#[test_only]
public fun create_config_for_testing(fee: u64, recipient: address): PaymentConfig {
    PaymentConfig { fee, recipient }
}

// === Tests ===

#[test]
fun test_paid_join_success() {
    use messaging::messaging;
    use sui::coin;

    let creator_ctx = &mut tx_context::dummy();
    let creator = creator_ctx.sender();

    // Create MessagingGroup (creator becomes member with all permissions)
    let mut group = messaging::new(creator_ctx);

    // Create policy with payment rule (10 MIST fee, creator receives payment)
    let (mut policy, cap) = join_policy::new_for_testing<TestWitness>(creator_ctx);
    add_rule(&mut policy, &cap, 10, creator);

    // New user wants to join
    let new_user = @0xCAFE;
    let user_ctx = &tx_context::new_from_hint(new_user, 0, 0, 0, 0);

    // Create join request
    let mut request = join_policy::new_join_request(&policy, user_ctx);

    // Pay to satisfy the rule
    let payment = coin::mint_for_testing<SUI>(10, creator_ctx);
    satisfy(&mut request, &policy, payment);

    // Confirm request - returns JoinApproval
    let approval = join_policy::confirm_request(&policy, request);

    // Add member to MessagingGroup using the approval
    group.add_member_with_approval(approval);

    // Verify member was added
    assert!(group.is_member(new_user));

    // Cleanup
    let _config = remove_rule(&mut policy, &cap);
    join_policy::destroy_policy_for_testing(policy);
    join_policy::destroy_cap_for_testing(cap);
    std::unit_test::destroy(group);
}

#[test]
#[expected_failure(abort_code = EInsufficientPayment)]
fun test_paid_join_insufficient_payment() {
    use messaging::messaging;
    use sui::coin;

    let creator_ctx = &mut tx_context::dummy();
    let creator = creator_ctx.sender();

    // Create MessagingGroup
    let mut group = messaging::new(creator_ctx);

    // Create policy with payment rule (10 MIST fee)
    let (mut policy, cap) = join_policy::new_for_testing<TestWitness>(creator_ctx);
    add_rule(&mut policy, &cap, 10, creator);

    // New user wants to join
    let new_user = @0xCAFE;
    let user_ctx = &tx_context::new_from_hint(new_user, 0, 0, 0, 0);

    // Create join request
    let mut request = join_policy::new_join_request(&policy, user_ctx);

    // Pay less than required - should fail
    let payment = coin::mint_for_testing<SUI>(5, creator_ctx);
    satisfy(&mut request, &policy, payment);

    // Won't reach here
    let approval = join_policy::confirm_request(&policy, request);
    group.add_member_with_approval(approval);

    // Cleanup (won't reach)
    let _config = remove_rule(&mut policy, &cap);
    join_policy::destroy_policy_for_testing(policy);
    join_policy::destroy_cap_for_testing(cap);
    std::unit_test::destroy(group);
}

#[test]
fun test_paid_join_overpayment_accepted() {
    use messaging::messaging;
    use sui::coin;

    let creator_ctx = &mut tx_context::dummy();
    let creator = creator_ctx.sender();

    // Create MessagingGroup
    let mut group = messaging::new(creator_ctx);

    // Create policy with payment rule (10 MIST fee)
    let (mut policy, cap) = join_policy::new_for_testing<TestWitness>(creator_ctx);
    add_rule(&mut policy, &cap, 10, creator);

    // New user wants to join
    let new_user = @0xCAFE;
    let user_ctx = &tx_context::new_from_hint(new_user, 0, 0, 0, 0);

    // Create join request
    let mut request = join_policy::new_join_request(&policy, user_ctx);

    // Pay more than required - should succeed (overpayment as tip/donation)
    let payment = coin::mint_for_testing<SUI>(100, creator_ctx);
    satisfy(&mut request, &policy, payment);

    // Confirm request - returns JoinApproval
    let approval = join_policy::confirm_request(&policy, request);

    // Add member to MessagingGroup using the approval
    group.add_member_with_approval(approval);

    // Verify member was added
    assert!(group.is_member(new_user));

    // Cleanup
    let _config = remove_rule(&mut policy, &cap);
    join_policy::destroy_policy_for_testing(policy);
    join_policy::destroy_cap_for_testing(cap);
    std::unit_test::destroy(group);
}

#[test]
fun test_getters() {
    let creator_ctx = &mut tx_context::dummy();
    let recipient = @0xBEEF;

    // Create policy with payment rule
    let (mut policy, cap) = join_policy::new_for_testing<TestWitness>(creator_ctx);
    add_rule(&mut policy, &cap, 42, recipient);

    // Test getters
    assert!(get_fee(&policy) == 42);
    assert!(get_recipient(&policy) == recipient);

    // Cleanup
    let _config = remove_rule(&mut policy, &cap);
    join_policy::destroy_policy_for_testing(policy);
    join_policy::destroy_cap_for_testing(cap);
}
