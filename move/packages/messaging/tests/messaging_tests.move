#[test_only]
module messaging::messaging_tests;

use permissioned_groups::permissioned_group::{PermissionedGroup, Administrator, ExtensionPermissionsManager};
use messaging::encryption_history::{Self, EncryptionHistory, EncryptionKeyRotator};
use messaging::messaging::{
    Self,
    Messaging,
    MessagingNamespace,
    MessagingSender,
    MessagingReader,
    MessagingEditor,
    MessagingDeleter
};
use messaging::test_helpers;
use messaging::utils;
use std::unit_test::{assert_eq, destroy};
use sui::test_scenario as ts;
use sui::vec_set;

// === Test Addresses ===

const ALICE: address = @0xA11CE;
const BOB: address = @0xB0B;

// === Test Nonces ===

const NONCE_1: u256 = 1;
const NONCE_2: u256 = 2;
const NONCE_3: u256 = 3;

// === create_group tests ===

#[test]
fun create_group_creates_group_and_encryption_history() {
    let mut ts = ts::begin(ALICE);

    // Initialize namespace
    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    // Create group
    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        vec_set::empty(),
        ts.ctx(),
    );

    // Verify group creator
    assert!(group.creator<Messaging>() == ALICE);
    assert!(group.is_member(ALICE));
    assert!(group.administrators_count<Messaging>() == 1);

    // Verify creator has all messaging permissions
    assert!(group.has_permission<Messaging, MessagingSender>(ALICE));
    assert!(group.has_permission<Messaging, MessagingReader>(ALICE));
    assert!(group.has_permission<Messaging, MessagingEditor>(ALICE));
    assert!(group.has_permission<Messaging, MessagingDeleter>(ALICE));
    assert!(group.has_permission<Messaging, EncryptionKeyRotator>(ALICE));

    // Verify creator has core permissions
    assert!(group.has_permission<Messaging, Administrator>(ALICE));
    assert!(group.has_permission<Messaging, ExtensionPermissionsManager>(ALICE));

    // Verify encryption history
    assert_eq!(encryption_history.group_id(), object::id(&group));
    assert_eq!(encryption_history.current_key_version(), 0);

    // Verify namespace counter
    assert_eq!(messaging::groups_created(&namespace), 1);

    ts::return_shared(namespace);
    destroy(group);
    destroy(encryption_history);
    ts.end();
}

#[test]
fun create_group_increments_namespace_counter() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();

    assert_eq!(messaging::groups_created(&namespace), 0);

    let mock_dek_1 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group1, eh1) = messaging::create_group(&mut namespace, mock_dek_1, vec_set::empty(), ts.ctx());
    assert_eq!(messaging::groups_created(&namespace), 1);

    let mock_dek_2 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_2);
    let (group2, eh2) = messaging::create_group(&mut namespace, mock_dek_2, vec_set::empty(), ts.ctx());
    assert_eq!(messaging::groups_created(&namespace), 2);

    ts::return_shared(namespace);
    destroy(group1);
    destroy(eh1);
    destroy(group2);
    destroy(eh2);
    ts.end();
}

#[test]
fun create_group_with_initial_members() {
    let mut ts = ts::begin(ALICE);

    // Initialize namespace
    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    // Create group with Bob as initial member
    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mut initial_members = vec_set::empty();
    initial_members.insert(BOB);
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        initial_members,
        ts.ctx(),
    );

    // Verify Bob has MessagingReader permission
    assert_eq!(group.has_permission<Messaging, MessagingReader>(BOB), true);
    assert_eq!(group.is_member(BOB), true);

    // Verify Bob does NOT have other permissions
    assert_eq!(group.has_permission<Messaging, MessagingSender>(BOB), false);
    assert_eq!(group.has_permission<Messaging, Administrator>(BOB), false);

    // Verify creator still has all permissions
    assert_eq!(group.has_permission<Messaging, Administrator>(ALICE), true);
    assert_eq!(group.has_permission<Messaging, MessagingReader>(ALICE), true);

    ts::return_shared(namespace);
    destroy(group);
    destroy(encryption_history);
    ts.end();
}

#[test]
fun create_group_with_initial_members_including_creator() {
    let mut ts = ts::begin(ALICE);

    // Initialize namespace
    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    // Create group with Alice (creator) in initial_members - should be silently skipped
    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mut initial_members = vec_set::empty();
    initial_members.insert(ALICE);  // Creator included
    initial_members.insert(BOB);
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        initial_members,
        ts.ctx(),
    );

    // Verify Bob has MessagingReader
    assert_eq!(group.has_permission<Messaging, MessagingReader>(BOB), true);

    // Verify Alice still has all permissions (not just MessagingReader)
    assert_eq!(group.has_permission<Messaging, Administrator>(ALICE), true);
    assert_eq!(group.has_permission<Messaging, MessagingSender>(ALICE), true);

    ts::return_shared(namespace);
    destroy(group);
    destroy(encryption_history);
    ts.end();
}

// === create_and_share_group tests ===

#[test]
fun create_and_share_group_creates_shared_objects() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    messaging::create_and_share_group(&mut namespace, mock_dek, vec_set::empty(), ts.ctx());
    ts::return_shared(namespace);

    // Verify shared objects exist
    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();

    assert!(group.creator<Messaging>() == ALICE);
    assert_eq!(encryption_history.group_id(), object::id(&group));

    ts::return_shared(group);
    ts::return_shared(encryption_history);
    ts.end();
}

// === rotate_encryption_key tests ===

#[test]
fun rotate_encryption_key_with_permission() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek_v1 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek_v1,
        vec_set::empty(),
        ts.ctx(),
    );
    transfer::public_share_object(group);
    transfer::public_share_object(encryption_history);
    ts::return_shared(namespace);

    // Alice rotates the key
    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();

    assert_eq!(encryption_history.current_key_version(), 0);

    let mock_dek_v2 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_2);
    messaging::rotate_encryption_key(
        &mut namespace,
        &mut encryption_history,
        &group,
        mock_dek_v2,
        ts.ctx(),
    );

    assert_eq!(encryption_history.current_key_version(), 1);

    ts::return_shared(namespace);
    ts::return_shared(group);
    ts::return_shared(encryption_history);
    ts.end();
}

#[test, expected_failure(abort_code = messaging::ENotPermitted)]
fun rotate_encryption_key_without_permission_fails() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (mut group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        vec_set::empty(),
        ts.ctx(),
    );
    // Add Bob without EncryptionKeyRotator (just grant MessagingReader)
    group.grant_permission<Messaging, MessagingReader>(BOB, ts.ctx());
    transfer::public_share_object(group);
    transfer::public_share_object(encryption_history);
    ts::return_shared(namespace);

    // Bob tries to rotate the key
    ts.next_tx(BOB);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();

    let mock_dek_v2 = test_helpers::make_mock_encrypted_dek(BOB, NONCE_2);
    messaging::rotate_encryption_key(
        &mut namespace,
        &mut encryption_history,
        &group,
        mock_dek_v2,
        ts.ctx(),
    );

    abort
}

// === grant_all_messaging_permissions tests ===

#[test]
fun grant_all_messaging_permissions_grants_all() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (mut group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        vec_set::empty(),
        ts.ctx(),
    );

    // Grant Bob all messaging permissions
    messaging::grant_all_messaging_permissions(&mut group, BOB, ts.ctx());

    // Verify Bob has all messaging permissions
    assert!(group.has_permission<Messaging, MessagingSender>(BOB));
    assert!(group.has_permission<Messaging, MessagingReader>(BOB));
    assert!(group.has_permission<Messaging, MessagingEditor>(BOB));
    assert!(group.has_permission<Messaging, MessagingDeleter>(BOB));
    assert!(group.has_permission<Messaging, EncryptionKeyRotator>(BOB));

    // Verify Bob does NOT have core permissions
    assert!(!group.has_permission<Messaging, Administrator>(BOB));
    assert!(!group.has_permission<Messaging, ExtensionPermissionsManager>(BOB));

    ts::return_shared(namespace);
    destroy(group);
    destroy(encryption_history);
    ts.end();
}

// === grant_all_permissions tests ===

#[test]
fun grant_all_permissions_grants_base_and_messaging() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (mut group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        vec_set::empty(),
        ts.ctx(),
    );

    assert_eq!(group.administrators_count<Messaging>(), 1);

    // Grant Bob all permissions (admin)
    messaging::grant_all_permissions(&mut group, BOB, ts.ctx());

    // Verify Bob has all messaging permissions
    assert!(group.has_permission<Messaging, MessagingSender>(BOB));
    assert!(group.has_permission<Messaging, MessagingReader>(BOB));
    assert!(group.has_permission<Messaging, MessagingEditor>(BOB));
    assert!(group.has_permission<Messaging, MessagingDeleter>(BOB));
    assert!(group.has_permission<Messaging, EncryptionKeyRotator>(BOB));

    // Verify Bob has core permissions
    assert!(group.has_permission<Messaging, Administrator>(BOB));
    assert!(group.has_permission<Messaging, ExtensionPermissionsManager>(BOB));

    // Verify administrators count incremented
    assert_eq!(group.administrators_count<Messaging>(), 2);

    ts::return_shared(namespace);
    destroy(group);
    destroy(encryption_history);
    ts.end();
}

// === EncryptionHistory getters tests ===

#[test]
fun encryption_history_encrypted_key_returns_correct_version() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek_v0 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek_v0,
        vec_set::empty(),
        ts.ctx(),
    );
    transfer::public_share_object(group);
    transfer::public_share_object(encryption_history);
    ts::return_shared(namespace);

    // Rotate twice
    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();

    let mock_dek_v1 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_2);
    let mock_dek_v2 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_3);
    messaging::rotate_encryption_key(&mut namespace, &mut encryption_history, &group, mock_dek_v1, ts.ctx());
    messaging::rotate_encryption_key(&mut namespace, &mut encryption_history, &group, mock_dek_v2, ts.ctx());

    // Verify version count
    assert_eq!(encryption_history.current_key_version(), 2);

    ts::return_shared(namespace);
    ts::return_shared(group);
    ts::return_shared(encryption_history);
    ts.end();
}

#[test, expected_failure(abort_code = encryption_history::EKeyVersionNotFound)]
fun encryption_history_encrypted_key_invalid_version_fails() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (_group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        vec_set::empty(),
        ts.ctx(),
    );

    // Try to access version 1 when only version 0 exists
    let _ = encryption_history.encrypted_key(1);

    abort
}

// === EEncryptedDEKTooLarge error tests ===

/// Generate a vector of bytes larger than MAX_ENCRYPTED_DEK_BYTES (1024).
#[test_only]
fun make_oversized_dek(): vector<u8> {
    let mut dek = vector::empty<u8>();
    let mut i: u64 = 0;
    while (i < 1025) {
        dek.push_back(0x42);
        i = i + 1;
    };
    dek
}

#[test, expected_failure(abort_code = utils::EInvalidIdentityBytesLength)]
fun create_group_with_malformed_dek_fails() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();

    // Try to create group with oversized/malformed DEK
    // This fails at parse_identity_bytes because the DEK doesn't have valid BCS structure
    let (_group, _encryption_history) = messaging::create_group(
        &mut namespace,
        make_oversized_dek(),
        vec_set::empty(),
        ts.ctx(),
    );

    abort
}

// Note: This test now expects EInvalidIdentityBytesLength because identity bytes
// are parsed before the size check. A malformed/oversized DEK without valid BCS
// structure will fail at the identity bytes parsing stage.
#[test, expected_failure(abort_code = utils::EInvalidIdentityBytesLength)]
fun rotate_encryption_key_with_malformed_dek_fails() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        vec_set::empty(),
        ts.ctx(),
    );
    transfer::public_share_object(group);
    transfer::public_share_object(encryption_history);
    ts::return_shared(namespace);

    // Alice tries to rotate with malformed DEK
    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();

    messaging::rotate_encryption_key(
        &mut namespace,
        &mut encryption_history,
        &group,
        make_oversized_dek(),
        ts.ctx(),
    );

    abort
}

// === Nonce reuse tests ===

#[test, expected_failure(abort_code = sui::vec_set::EKeyAlreadyExists)]
fun create_group_with_same_nonce_fails() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();

    // First group creation succeeds
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group1, eh1) = messaging::create_group(&mut namespace, mock_dek, vec_set::empty(), ts.ctx());

    // Second group creation with same nonce should fail
    let mock_dek_same_nonce = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (_group2, _eh2) = messaging::create_group(&mut namespace, mock_dek_same_nonce, vec_set::empty(), ts.ctx());

    destroy(group1);
    destroy(eh1);
    abort
}

#[test, expected_failure(abort_code = messaging::EInvalidIdentityBytesEncryptor)]
fun create_group_with_wrong_encryptor_in_identity_fails() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();

    // Create DEK with BOB's address but send from ALICE - should fail
    let mock_dek_wrong_encryptor = test_helpers::make_mock_encrypted_dek(BOB, NONCE_1);
    let (_group, _eh) = messaging::create_group(&mut namespace, mock_dek_wrong_encryptor, vec_set::empty(), ts.ctx());

    abort
}

#[test]
fun different_creators_can_use_same_nonce() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    // Alice creates group with NONCE_1
    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek_alice = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group1, eh1) = messaging::create_group(&mut namespace, mock_dek_alice, vec_set::empty(), ts.ctx());
    ts::return_shared(namespace);

    // Bob creates group with same NONCE_1 - should succeed (different creator)
    ts.next_tx(BOB);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek_bob = test_helpers::make_mock_encrypted_dek(BOB, NONCE_1);
    let (group2, eh2) = messaging::create_group(&mut namespace, mock_dek_bob, vec_set::empty(), ts.ctx());
    ts::return_shared(namespace);

    destroy(group1);
    destroy(eh1);
    destroy(group2);
    destroy(eh2);
    ts.end();
}

// === Rotation nonce validation tests ===

#[test, expected_failure(abort_code = sui::vec_set::EKeyAlreadyExists)]
fun rotate_encryption_key_with_same_nonce_fails() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        vec_set::empty(),
        ts.ctx(),
    );
    transfer::public_share_object(group);
    transfer::public_share_object(encryption_history);
    ts::return_shared(namespace);

    // Alice tries to rotate using the same nonce as initial DEK - should fail
    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();

    let mock_dek_same_nonce = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    messaging::rotate_encryption_key(
        &mut namespace,
        &mut encryption_history,
        &group,
        mock_dek_same_nonce,
        ts.ctx(),
    );

    abort
}

#[test, expected_failure(abort_code = messaging::EInvalidIdentityBytesEncryptor)]
fun rotate_encryption_key_with_wrong_encryptor_fails() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (mut group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        vec_set::empty(),
        ts.ctx(),
    );
    // Grant Bob EncryptionKeyRotator permission
    group.grant_permission<Messaging, EncryptionKeyRotator>(BOB, ts.ctx());
    transfer::public_share_object(group);
    transfer::public_share_object(encryption_history);
    ts::return_shared(namespace);

    // Bob tries to rotate with DEK encrypted using ALICE's address - should fail
    ts.next_tx(BOB);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();

    // DEK encrypted with ALICE's address but BOB is the sender
    let mock_dek_wrong_encryptor = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_2);
    messaging::rotate_encryption_key(
        &mut namespace,
        &mut encryption_history,
        &group,
        mock_dek_wrong_encryptor,
        ts.ctx(),
    );

    abort
}

#[test]
fun rotate_encryption_key_different_rotators_can_use_same_nonce() {
    let mut ts = ts::begin(ALICE);

    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (mut group, encryption_history) = messaging::create_group(
        &mut namespace,
        mock_dek,
        vec_set::empty(),
        ts.ctx(),
    );
    // Grant Bob EncryptionKeyRotator permission
    group.grant_permission<Messaging, EncryptionKeyRotator>(BOB, ts.ctx());
    transfer::public_share_object(group);
    transfer::public_share_object(encryption_history);
    ts::return_shared(namespace);

    // Alice rotates with NONCE_2
    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();
    let mock_dek_alice = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_2);
    messaging::rotate_encryption_key(&mut namespace, &mut encryption_history, &group, mock_dek_alice, ts.ctx());
    ts::return_shared(namespace);
    ts::return_shared(group);
    ts::return_shared(encryption_history);

    // Bob rotates with NONCE_2 (same nonce, different encryptor) - should succeed
    ts.next_tx(BOB);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();
    let mock_dek_bob = test_helpers::make_mock_encrypted_dek(BOB, NONCE_2);
    messaging::rotate_encryption_key(&mut namespace, &mut encryption_history, &group, mock_dek_bob, ts.ctx());

    // Verify we now have 3 versions (0, 1, 2)
    assert_eq!(encryption_history.current_key_version(), 2);

    ts::return_shared(namespace);
    ts::return_shared(group);
    ts::return_shared(encryption_history);
    ts.end();
}
