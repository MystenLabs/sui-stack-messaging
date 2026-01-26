#[test_only]
module messaging::seal_policies_tests;

use permissioned_groups::permissioned_group::PermissionedGroup;
use messaging::encryption_history::EncryptionHistory;
use messaging::messaging::{Self, Messaging, MessagingNamespace, MessagingReader, MessagingSender};
use messaging::seal_policies;
use messaging::test_helpers;
use sui::test_scenario as ts;
use sui::vec_set;

// === Test Addresses ===

const ALICE: address = @0xA11CE;
const BOB: address = @0xB0B;

// === Test Nonces ===

const NONCE_1: u256 = 1;
const NONCE_2: u256 = 2;

/// Sets up a messaging group and returns the mock DEK used (for identity extraction).
#[test_only]
fun setup_group(ts: &mut ts::Scenario): vector<u8> {
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

    // Return the mock DEK so tests can extract correct identity bytes
    test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1)
}

/// Extracts identity bytes from mock encrypted DEK for use in seal_approve calls.
#[test_only]
fun get_identity_bytes(creator: address, nonce: u256): vector<u8> {
    use messaging::utils;
    let mock_dek = test_helpers::make_mock_encrypted_dek(creator, nonce);
    utils::parse_identity_bytes(&mock_dek)
}

// === seal_approve_reader tests ===

#[test]
fun seal_approve_reader_with_valid_identity_and_permission() {
    let mut ts = ts::begin(ALICE);
    setup_group(&mut ts);

    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();

    // Get the identity bytes that were stored when group was created
    let id = get_identity_bytes(ALICE, NONCE_1);

    // Alice has MessagingReader permission (granted on group creation)
    seal_policies::seal_approve_reader(id, &encryption_history, &group, ts.ctx());

    ts::return_shared(group);
    ts::return_shared(encryption_history);
    ts.end();
}

#[test]
fun seal_approve_reader_member_with_reader_permission() {
    let mut ts = ts::begin(ALICE);
    setup_group(&mut ts);

    // Alice grants Bob MessagingReader
    ts.next_tx(ALICE);
    let mut group = ts.take_shared<PermissionedGroup<Messaging>>();
    group.grant_permission<Messaging, MessagingReader>(BOB, ts.ctx());
    ts::return_shared(group);

    // Bob should be able to approve with correct identity bytes
    ts.next_tx(BOB);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();
    let id = get_identity_bytes(ALICE, NONCE_1);

    seal_policies::seal_approve_reader(id, &encryption_history, &group, ts.ctx());

    ts::return_shared(group);
    ts::return_shared(encryption_history);
    ts.end();
}

#[test, expected_failure(abort_code = seal_policies::EInvalidIdentityBytes)]
fun seal_approve_reader_with_wrong_identity_fails() {
    let mut ts = ts::begin(ALICE);
    setup_group(&mut ts);

    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();

    // Use wrong nonce - identity bytes won't match stored version
    let wrong_id = get_identity_bytes(ALICE, NONCE_2);

    seal_policies::seal_approve_reader(wrong_id, &encryption_history, &group, ts.ctx());

    abort
}

#[test, expected_failure(abort_code = seal_policies::EInvalidIdentityBytes)]
fun seal_approve_reader_with_wrong_creator_fails() {
    let mut ts = ts::begin(ALICE);
    setup_group(&mut ts);

    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();

    // Use BOB's address instead of ALICE's - identity bytes won't match
    let wrong_id = get_identity_bytes(BOB, NONCE_1);

    seal_policies::seal_approve_reader(wrong_id, &encryption_history, &group, ts.ctx());

    abort
}

#[test, expected_failure(abort_code = seal_policies::ENotPermitted)]
fun seal_approve_reader_without_permission_fails() {
    let mut ts = ts::begin(ALICE);
    setup_group(&mut ts);

    // Alice grants Bob a permission but NOT MessagingReader
    ts.next_tx(ALICE);
    let mut group = ts.take_shared<PermissionedGroup<Messaging>>();
    group.grant_permission<Messaging, MessagingSender>(BOB, ts.ctx());
    ts::return_shared(group);

    // Bob tries to approve but doesn't have MessagingReader
    ts.next_tx(BOB);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();
    let id = get_identity_bytes(ALICE, NONCE_1);

    seal_policies::seal_approve_reader(id, &encryption_history, &group, ts.ctx());

    abort
}

#[test, expected_failure]
fun seal_approve_reader_non_member_fails() {
    let mut ts = ts::begin(ALICE);
    setup_group(&mut ts);

    // Bob is not a member at all
    ts.next_tx(BOB);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();
    let id = get_identity_bytes(ALICE, NONCE_1);

    seal_policies::seal_approve_reader(id, &encryption_history, &group, ts.ctx());

    abort
}

// === seal_approve_reader_for_version tests ===

#[test]
fun seal_approve_reader_for_version_validates_specific_version() {
    let mut ts = ts::begin(ALICE);
    setup_group(&mut ts);

    // Rotate key to create version 1
    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();
    let mock_dek_v1 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_2);
    messaging::rotate_encryption_key(&mut encryption_history, &group, mock_dek_v1, ts.ctx());
    ts::return_shared(group);
    ts::return_shared(encryption_history);

    // Verify we can approve for version 0 with original identity
    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();
    let id_v0 = get_identity_bytes(ALICE, NONCE_1);
    seal_policies::seal_approve_reader_for_version(id_v0, 0, &encryption_history, &group, ts.ctx());
    ts::return_shared(group);
    ts::return_shared(encryption_history);

    // Verify we can approve for version 1 with new identity
    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();
    let id_v1 = get_identity_bytes(ALICE, NONCE_2);
    seal_policies::seal_approve_reader_for_version(id_v1, 1, &encryption_history, &group, ts.ctx());

    ts::return_shared(group);
    ts::return_shared(encryption_history);
    ts.end();
}

#[test, expected_failure(abort_code = seal_policies::EInvalidIdentityBytes)]
fun seal_approve_reader_for_version_wrong_version_fails() {
    let mut ts = ts::begin(ALICE);
    setup_group(&mut ts);

    // Rotate key to create version 1
    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();
    let mock_dek_v1 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_2);
    messaging::rotate_encryption_key(&mut encryption_history, &group, mock_dek_v1, ts.ctx());
    ts::return_shared(group);
    ts::return_shared(encryption_history);

    // Try to approve for version 0 with version 1's identity - should fail
    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();
    let id_v1 = get_identity_bytes(ALICE, NONCE_2);

    // Using v1 identity for v0 should fail
    seal_policies::seal_approve_reader_for_version(id_v1, 0, &encryption_history, &group, ts.ctx());

    abort
}

// === seal_approve_reader uses current version ===

#[test]
fun seal_approve_reader_uses_current_version_after_rotation() {
    let mut ts = ts::begin(ALICE);
    setup_group(&mut ts);

    // Rotate key to create version 1
    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();
    let mock_dek_v1 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_2);
    messaging::rotate_encryption_key(&mut encryption_history, &group, mock_dek_v1, ts.ctx());
    ts::return_shared(group);
    ts::return_shared(encryption_history);

    // seal_approve_reader should now use version 1's identity
    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();
    let id_v1 = get_identity_bytes(ALICE, NONCE_2);
    seal_policies::seal_approve_reader(id_v1, &encryption_history, &group, ts.ctx());

    ts::return_shared(group);
    ts::return_shared(encryption_history);
    ts.end();
}

#[test, expected_failure(abort_code = seal_policies::EInvalidIdentityBytes)]
fun seal_approve_reader_rejects_old_version_identity() {
    let mut ts = ts::begin(ALICE);
    setup_group(&mut ts);

    // Rotate key to create version 1
    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let mut encryption_history = ts.take_shared<EncryptionHistory>();
    let mock_dek_v1 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_2);
    messaging::rotate_encryption_key(&mut encryption_history, &group, mock_dek_v1, ts.ctx());
    ts::return_shared(group);
    ts::return_shared(encryption_history);

    // seal_approve_reader with v0 identity should fail (current is v1)
    ts.next_tx(ALICE);
    let group = ts.take_shared<PermissionedGroup<Messaging>>();
    let encryption_history = ts.take_shared<EncryptionHistory>();
    let id_v0 = get_identity_bytes(ALICE, NONCE_1);

    seal_policies::seal_approve_reader(id_v0, &encryption_history, &group, ts.ctx());

    abort
}

// === EGroupMismatch tests ===

#[test, expected_failure(abort_code = seal_policies::EGroupMismatch)]
fun seal_approve_reader_with_wrong_encryption_history_fails() {
    let mut ts = ts::begin(ALICE);

    // Setup first group
    ts.next_tx(ALICE);
    messaging::init_for_testing(ts.ctx());

    ts.next_tx(ALICE);
    let mut namespace = ts.take_shared<MessagingNamespace>();
    let mock_dek_1 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_1);
    let (group1, encryption_history1) = messaging::create_group(
        &mut namespace,
        mock_dek_1,
        vec_set::empty(),
        ts.ctx(),
    );
    let group1_id = object::id(&group1);
    transfer::public_share_object(group1);
    transfer::public_share_object(encryption_history1);

    // Create second group
    let mock_dek_2 = test_helpers::make_mock_encrypted_dek(ALICE, NONCE_2);
    let (group2, encryption_history2) = messaging::create_group(
        &mut namespace,
        mock_dek_2,
        vec_set::empty(),
        ts.ctx(),
    );
    let encryption_history2_id = object::id(&encryption_history2);
    transfer::public_share_object(group2);
    transfer::public_share_object(encryption_history2);
    ts::return_shared(namespace);

    // Try to use group1 with encryption_history2 - should fail
    ts.next_tx(ALICE);
    let group1 = ts.take_shared_by_id<PermissionedGroup<Messaging>>(group1_id);
    let encryption_history2 = ts.take_shared_by_id<EncryptionHistory>(encryption_history2_id);
    let id = get_identity_bytes(ALICE, NONCE_2);  // From group2

    seal_policies::seal_approve_reader(id, &encryption_history2, &group1, ts.ctx());

    abort
}
