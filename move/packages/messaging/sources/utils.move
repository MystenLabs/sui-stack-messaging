/// Module: utils
///
/// Utility functions for identity bytes parsing and validation.
/// Identity bytes format: [creator_address (32 bytes)][nonce (32 bytes)]
module messaging::utils;

use sui::bcs;

// === Constants ===

/// Expected length of identity bytes: creator_address (32 bytes) + nonce (32 bytes)
const IDENTITY_BYTES_LENGTH: u64 = 64;

// === Error Codes ===

const EInvalidIdentityBytesLength: u64 = 0;

// === Public Functions ===

/// Checks if `prefix` is a prefix of `data`.
///
/// # Parameters
/// - `prefix`: The prefix to check
/// - `data`: The data to check against
///
/// # Returns
/// `true` if `prefix` is a prefix of `data`, `false` otherwise.
public fun is_prefix(prefix: &vector<u8>, data: &vector<u8>): bool {
    let prefix_len = prefix.length();
    if (prefix_len > data.length()) {
        return false
    };
    let mut i = 0;
    while (i < prefix_len) {
        if (prefix[i] != data[i]) {
            return false
        };
        i = i + 1;
    };
    true
}

/// Parses the identity bytes from a Seal EncryptedObject.
///
/// EncryptedObject BCS layout:
/// - version: u8
/// - packageId: address (32 bytes)
/// - id: vector<u8> (ULEB128 length + bytes) <- this is identity_bytes
/// - ... (remaining fields ignored)
///
/// # Parameters
/// - `encrypted_dek`: The BCS-serialized Seal EncryptedObject bytes
///
/// # Returns
/// The identity bytes extracted from the EncryptedObject.
///
/// # Aborts
/// - `EInvalidIdentityBytesLength`: if identity bytes are not exactly 64 bytes
public fun parse_identity_bytes(encrypted_dek: &vector<u8>): vector<u8> {
    let mut bcs_data = bcs::new(*encrypted_dek);
    let _version = bcs_data.peel_u8();
    let _package_id = bcs_data.peel_address();
    let identity_bytes = bcs_data.peel_vec_u8();

    assert!(identity_bytes.length() == IDENTITY_BYTES_LENGTH, EInvalidIdentityBytesLength);

    identity_bytes
}

/// Unpacks identity bytes into creator address and nonce.
///
/// Uses Sui's BCS module for efficient sequential parsing without
/// intermediate vector allocations.
///
/// # Parameters
/// - `identity_bytes`: 64-byte vector in format [creator_address][nonce]
///
/// # Returns
/// Tuple of (creator_address, nonce_as_u256).
///
/// # Aborts
/// - `EInvalidIdentityBytesLength`: if identity_bytes is not exactly 64 bytes
public fun unpack_identity_bytes(identity_bytes: vector<u8>): (address, u256) {
    assert!(identity_bytes.length() == IDENTITY_BYTES_LENGTH, EInvalidIdentityBytesLength);

    let mut bcs_data = bcs::new(identity_bytes);
    let creator = bcs_data.peel_address();
    let nonce = bcs_data.peel_u256();

    (creator, nonce)
}

// === Unit Tests ===

#[test]
fun test_is_prefix_returns_true_for_valid_prefix() {
    let prefix = vector[1u8, 2, 3];
    let data = vector[1u8, 2, 3, 4, 5];
    assert!(is_prefix(&prefix, &data));
}

#[test]
fun test_is_prefix_returns_true_for_exact_match() {
    let prefix = vector[1u8, 2, 3];
    let data = vector[1u8, 2, 3];
    assert!(is_prefix(&prefix, &data));
}

#[test]
fun test_is_prefix_returns_false_for_non_prefix() {
    let prefix = vector[1u8, 2, 4];
    let data = vector[1u8, 2, 3, 4, 5];
    assert!(!is_prefix(&prefix, &data));
}

#[test]
fun test_is_prefix_returns_false_when_prefix_longer_than_data() {
    let prefix = vector[1u8, 2, 3, 4, 5, 6];
    let data = vector[1u8, 2, 3];
    assert!(!is_prefix(&prefix, &data));
}

#[test]
fun test_is_prefix_returns_true_for_empty_prefix() {
    let prefix = vector::empty<u8>();
    let data = vector[1u8, 2, 3];
    assert!(is_prefix(&prefix, &data));
}

#[test]
fun test_unpack_identity_bytes_extracts_creator_and_nonce() {
    // Create 64-byte identity: 32-byte address + 32-byte nonce
    let mut identity = vector::empty<u8>();

    // Creator address: 0x01 followed by 31 zeros
    identity.push_back(0x01);
    let mut i: u64 = 0;
    while (i < 31) {
        identity.push_back(0x00);
        i = i + 1;
    };

    // Nonce: 0x42 followed by 31 zeros (little-endian u256 = 0x42)
    identity.push_back(0x42);
    i = 0;
    while (i < 31) {
        identity.push_back(0x00);
        i = i + 1;
    };

    let (creator, nonce) = unpack_identity_bytes(identity);

    // Verify creator address
    assert!(creator == @0x0100000000000000000000000000000000000000000000000000000000000000);

    // Verify nonce (little-endian: 0x42 in first byte = 66 decimal)
    assert!(nonce == 0x42);
}

#[test, expected_failure(abort_code = EInvalidIdentityBytesLength)]
fun test_unpack_identity_bytes_fails_for_short_input() {
    let short_identity = vector[1u8, 2, 3];
    let (_creator, _nonce) = unpack_identity_bytes(short_identity);
}

#[test, expected_failure(abort_code = EInvalidIdentityBytesLength)]
fun test_unpack_identity_bytes_fails_for_long_input() {
    let mut long_identity = vector::empty<u8>();
    let mut i: u64 = 0;
    while (i < 65) {
        long_identity.push_back(0x00);
        i = i + 1;
    };
    let (_creator, _nonce) = unpack_identity_bytes(long_identity);
}
