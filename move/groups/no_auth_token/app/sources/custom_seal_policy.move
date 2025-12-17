/// Module: custom_seal_policy
///
/// Example third-party app contract demonstrating subscription-based access control
/// for encrypted messaging content using a custom seal_approve function.
///
/// ## Pattern Overview
///
/// This pattern implements subscription-based access to encrypted content:
/// - A service owner creates a Service linked to a MessagingGroup
/// - Users purchase time-limited Subscriptions by paying SUI
/// - The custom seal_approve validates subscription ownership and expiry
///
/// ## Key Design Points
///
/// 1. **No wrapper needed**: This pattern doesn't wrap MessagingGroup. Instead, it:
///    - References the MessagingGroup by ID (stored in Service)
///    - Uses its own packageId for Seal encryption namespace
///
/// 2. **TS-SDK integration**: The SDK only needs to know:
///    - This package ID (for seal_approve calls)
///    - The Service object ID (for namespace prefix)
///
/// 3. **Namespace**: Uses Service ID as namespace prefix, format: [service_id][nonce]
///
/// ## Usage Flow
///
/// 1. Create MessagingGroup using messaging::messaging::new_with_encryption()
/// 2. Create Service via create_service(group_id, fee, ttl)
/// 3. Users subscribe via subscribe(service, payment, clock)
/// 4. Encrypt content using this package's ID and service.id as namespace
/// 5. seal_approve validates subscription before decryption
///
module app::custom_seal_policy;

use messaging::messaging::MessagingGroup;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::sui::SUI;

// === Error Codes ===

const EInvalidFee: u64 = 0;
const ENoAccess: u64 = 1;

// === Structs ===

/// A subscription service that gates access to a MessagingGroup's encrypted content.
/// The service can be shared so anyone can subscribe.
public struct Service has key {
    id: UID,
    /// The MessagingGroup this service is associated with (for reference only)
    group_id: ID,
    /// Subscription fee in MIST
    fee: u64,
    /// Time-to-live for subscriptions in milliseconds
    ttl: u64,
    /// Address that receives subscription payments
    owner: address,
}

/// A time-limited subscription to a Service.
/// Only has `key` (no `store`) so it can only be transferred, not wrapped.
public struct Subscription has key {
    id: UID,
    /// The service this subscription belongs to
    service_id: ID,
    /// Timestamp (ms) when the subscription was created
    created_at: u64,
}

// === Service Management ===

/// Creates a new subscription service for a MessagingGroup.
///
/// # Parameters
/// - `group_id`: The ID of the MessagingGroup this service controls access to
/// - `fee`: Subscription fee in MIST
/// - `ttl`: Subscription duration in milliseconds
/// - `ctx`: Transaction context
///
/// # Returns
/// - A new Service object (should be shared for public access)
public fun create_service(
    group_id: ID,
    fee: u64,
    ttl: u64,
    ctx: &mut TxContext,
): Service {
    Service {
        id: object::new(ctx),
        group_id,
        fee,
        ttl,
        owner: ctx.sender(),
    }
}

/// Creates and shares a new subscription service.
/// Convenience entry function for simpler CLI usage.
entry fun create_service_and_share(
    group_id: ID,
    fee: u64,
    ttl: u64,
    ctx: &mut TxContext,
) {
    transfer::share_object(create_service(group_id, fee, ttl, ctx));
}

// === Subscription Management ===

/// Purchases a subscription to the service.
/// The subscription is valid for `service.ttl` milliseconds from creation.
///
/// # Parameters
/// - `service`: Reference to the Service
/// - `payment`: SUI coin for payment (must equal service.fee)
/// - `clock`: Clock for timestamp
/// - `ctx`: Transaction context
///
/// # Returns
/// - A new Subscription object
///
/// # Aborts
/// - If payment amount doesn't match service fee
public fun subscribe(
    service: &Service,
    payment: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
): Subscription {
    assert!(payment.value() == service.fee, EInvalidFee);

    // Transfer payment to service owner
    transfer::public_transfer(payment, service.owner);

    Subscription {
        id: object::new(ctx),
        service_id: object::id(service),
        created_at: clock.timestamp_ms(),
    }
}

/// Purchases a subscription and transfers it to the sender.
/// Convenience entry function for simpler CLI usage.
entry fun subscribe_entry(
    service: &Service,
    payment: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let sub = subscribe(service, payment, clock, ctx);
    transfer::transfer(sub, ctx.sender());
}

/// Transfers a subscription to another address.
/// This allows gifting or selling subscriptions.
public fun transfer_subscription(sub: Subscription, to: address) {
    transfer::transfer(sub, to);
}

// === Getters ===

/// Returns the fee for this service.
public fun fee(service: &Service): u64 {
    service.fee
}

/// Returns the TTL for this service.
public fun ttl(service: &Service): u64 {
    service.ttl
}

/// Returns the MessagingGroup ID this service is associated with.
public fun group_id(service: &Service): ID {
    service.group_id
}

/// Returns the service ID this subscription belongs to.
public fun subscription_service_id(sub: &Subscription): ID {
    sub.service_id
}

/// Returns when this subscription was created.
public fun created_at(sub: &Subscription): u64 {
    sub.created_at
}

/// Checks if a subscription is still valid (not expired).
public fun is_subscription_valid(sub: &Subscription, service: &Service, clock: &Clock): bool {
    if (object::id(service) != sub.service_id) {
        return false
    };
    clock.timestamp_ms() <= sub.created_at + service.ttl
}

// === Seal Approve ===

/// Validates that the id has the correct namespace prefix (service ID).
/// The service ID is used as the namespace to identify which service's content
/// is being accessed.
///
/// Namespace format: [service_id (32 bytes)][nonce (variable)]
fun check_namespace(service: &Service, id: &vector<u8>): bool {
    let namespace = object::id(service).to_bytes();
    let namespace_len = namespace.length();

    if (namespace_len > id.length()) {
        return false
    };

    let mut i = 0;
    while (i < namespace_len) {
        if (namespace[i] != id[i]) {
            return false
        };
        i = i + 1;
    };
    true
}

/// Checks all conditions for seal approval.
/// Returns true if the subscription is valid, namespace matches, and caller is a member.
fun check_policy(
    id: &vector<u8>,
    sub: &Subscription,
    service: &Service,
    group: &MessagingGroup,
    clock: &Clock,
    ctx: &TxContext,
): bool {
    // Check if group matches the service's group_id
    if (object::id(group) != service.group_id) {
        return false
    };

    // Check if caller is a member of the group
    if (!group.is_member(ctx.sender())) {
        return false
    };

    // Check if subscription belongs to this service
    if (object::id(service) != sub.service_id) {
        return false
    };

    // Check if subscription has expired
    if (clock.timestamp_ms() > sub.created_at + service.ttl) {
        return false
    };

    // Check if the id has the correct namespace prefix
    check_namespace(service, id)
}

/// Custom seal_approve for subscription-based access.
/// Called by Seal key servers (via dry-run) to authorize decryption.
///
/// # Parameters
/// - `id`: The Seal identity bytes (format: [service_id][nonce])
/// - `sub`: The user's Subscription object
/// - `service`: The Service being accessed
/// - `group`: The MessagingGroup (must match service.group_id)
/// - `clock`: Clock for expiry validation
/// - `ctx`: Transaction context for sender verification
///
/// # Aborts
/// - If group doesn't match service.group_id
/// - If caller is not a member of the group
/// - If subscription doesn't belong to this service
/// - If subscription has expired
/// - If namespace prefix doesn't match service ID
entry fun seal_approve(
    id: vector<u8>,
    sub: &Subscription,
    service: &Service,
    group: &MessagingGroup,
    clock: &Clock,
    ctx: &TxContext,
) {
    assert!(check_policy(&id, sub, service, group, clock, ctx), ENoAccess);
}

// === Test Helpers ===

#[test_only]
public fun create_service_for_testing(
    group_id: ID,
    fee: u64,
    ttl: u64,
    ctx: &mut TxContext,
): Service {
    create_service(group_id, fee, ttl, ctx)
}

#[test_only]
public fun destroy_service_for_testing(service: Service) {
    let Service { id, .. } = service;
    object::delete(id);
}

#[test_only]
public fun destroy_subscription_for_testing(sub: Subscription) {
    let Subscription { id, .. } = sub;
    object::delete(id);
}

// === Tests ===

#[test]
fun test_subscription_flow() {
    use messaging::messaging;
    use sui::clock;
    use sui::coin;

    let ctx = &mut tx_context::dummy();
    let mut clock = clock::create_for_testing(ctx);

    // Create a MessagingGroup - sender becomes creator and member
    let group = messaging::new(ctx);
    let group_id = object::id(&group);

    // Create a service linked to this group
    let service = create_service(group_id, 10, 1000, ctx);

    // Subscribe with correct fee
    let payment = coin::mint_for_testing<SUI>(10, ctx);
    let sub = subscribe(&service, payment, &clock, ctx);

    // Build test ID with service namespace
    let mut test_id = object::id(&service).to_bytes();
    test_id.push_back(42); // nonce

    // Should pass at time 0
    assert!(check_policy(&test_id, &sub, &service, &group, &clock, ctx));

    // Should pass at time 500 (within TTL)
    clock.increment_for_testing(500);
    assert!(check_policy(&test_id, &sub, &service, &group, &clock, ctx));

    // Should pass at time 1000 (exactly at TTL boundary)
    clock.increment_for_testing(500);
    assert!(check_policy(&test_id, &sub, &service, &group, &clock, ctx));

    // Should fail at time 1001 (expired)
    clock.increment_for_testing(1);
    assert!(!check_policy(&test_id, &sub, &service, &group, &clock, ctx));

    // Cleanup
    destroy_service_for_testing(service);
    destroy_subscription_for_testing(sub);
    clock.destroy_for_testing();
    std::unit_test::destroy(group);
}

#[test]
fun test_wrong_namespace() {
    use messaging::messaging;
    use sui::clock;
    use sui::coin;

    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);

    // Create a MessagingGroup
    let group = messaging::new(ctx);
    let group_id = object::id(&group);

    let service = create_service(group_id, 10, 1000, ctx);

    let payment = coin::mint_for_testing<SUI>(10, ctx);
    let sub = subscribe(&service, payment, &clock, ctx);

    // Test with wrong namespace prefix
    let wrong_id = vector[1, 2, 3, 4];
    assert!(!check_policy(&wrong_id, &sub, &service, &group, &clock, ctx));

    // Cleanup
    destroy_service_for_testing(service);
    destroy_subscription_for_testing(sub);
    clock.destroy_for_testing();
    std::unit_test::destroy(group);
}

#[test]
fun test_wrong_group() {
    use messaging::messaging;
    use sui::clock;
    use sui::coin;

    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);

    // Create two different MessagingGroups
    let group1 = messaging::new(ctx);
    let group2 = messaging::new(ctx);
    let group1_id = object::id(&group1);

    // Service is linked to group1
    let service = create_service(group1_id, 10, 1000, ctx);

    let payment = coin::mint_for_testing<SUI>(10, ctx);
    let sub = subscribe(&service, payment, &clock, ctx);

    // Build test ID with service namespace
    let mut test_id = object::id(&service).to_bytes();
    test_id.push_back(42);

    // Should fail when passing group2 instead of group1
    assert!(!check_policy(&test_id, &sub, &service, &group2, &clock, ctx));

    // Cleanup
    destroy_service_for_testing(service);
    destroy_subscription_for_testing(sub);
    clock.destroy_for_testing();
    std::unit_test::destroy(group1);
    std::unit_test::destroy(group2);
}
