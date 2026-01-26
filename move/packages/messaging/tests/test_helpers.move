/// Module: test_helpers
///
/// Test utilities for creating mock encrypted DEKs with valid format.
/// These helpers generate BCS-serialized Seal EncryptedObject structures
/// that pass the `parse_identity_bytes` validation.
#[test_only]
module messaging::test_helpers;

use sui::bcs;

// === Constants ===

/// Mock package ID for Seal EncryptedObject (all zeros).
const MOCK_PACKAGE_ID: address = @0x0;

/// Seal EncryptedObject version (always 0 for our mocks).
const SEAL_VERSION: u8 = 0;

// === Public Functions ===

/// Creates a mock encrypted DEK with valid Seal EncryptedObject format.
///
/// The resulting bytes are BCS-serialized with the structure:
/// - version: u8 (0)
/// - packageId: address (32 bytes, all zeros)
/// - id: vector<u8> (64 bytes identity: [creator_address][nonce])
///
/// # Parameters
/// - `creator`: The creator address to embed in identity bytes
/// - `nonce`: The nonce to embed in identity bytes (as u256)
///
/// # Returns
/// BCS-serialized mock encrypted DEK bytes.
#[test_only]
public fun make_mock_encrypted_dek(creator: address, nonce: u256): vector<u8> {
    // Build identity bytes: [creator_address (32 bytes)][nonce (32 bytes)]
    let identity_bytes = build_identity_bytes(creator, nonce);

    // BCS serialize in order: version, packageId, identity_bytes (as vector)
    let mut result = vector::empty<u8>();

    // Append version (u8)
    result.push_back(SEAL_VERSION);

    // Append package ID (address = 32 bytes)
    let mock_package_id = MOCK_PACKAGE_ID;
    let package_bytes = bcs::to_bytes(&mock_package_id);
    package_bytes.do!(|byte| result.push_back(byte));

    // Append identity bytes as vector<u8> (ULEB128 length prefix + bytes)
    // For 64 bytes, ULEB128 encoding of 64 is just 0x40 (single byte)
    result.push_back(64u8); // length prefix
    identity_bytes.do!(|byte| result.push_back(byte));

    result
}

/// Creates a mock encrypted DEK with a simple incrementing nonce.
/// Useful for tests that need multiple unique DEKs.
///
/// # Parameters
/// - `creator`: The creator address
/// - `nonce_value`: A simple u64 value to use as nonce (converted to u256)
///
/// # Returns
/// BCS-serialized mock encrypted DEK bytes.
#[test_only]
public fun make_mock_encrypted_dek_simple(creator: address, nonce_value: u64): vector<u8> {
    make_mock_encrypted_dek(creator, (nonce_value as u256))
}

// === Private Functions ===

/// Builds 64-byte identity bytes from creator address and nonce.
/// Format: [creator_address (32 bytes)][nonce (32 bytes, little-endian)]
#[test_only]
fun build_identity_bytes(creator: address, nonce: u256): vector<u8> {
    let mut result = vector::empty<u8>();

    // Append creator address (32 bytes)
    let creator_bytes = bcs::to_bytes(&creator);
    creator_bytes.do!(|byte| result.push_back(byte));

    // Append nonce as little-endian u256 (32 bytes)
    let nonce_bytes = bcs::to_bytes(&nonce);
    nonce_bytes.do!(|byte| result.push_back(byte));

    result
}

// === Unit Tests ===

#[test]
fun test_make_mock_encrypted_dek_produces_valid_format() {
    use messaging::utils;

    let creator = @0xA11CE;
    let nonce: u256 = 12345;

    let encrypted_dek = make_mock_encrypted_dek(creator, nonce);

    // Should be parseable by utils::parse_identity_bytes
    let identity_bytes = utils::parse_identity_bytes(&encrypted_dek);

    // Identity bytes should be 64 bytes
    assert!(identity_bytes.length() == 64);
}

#[test]
fun test_make_mock_encrypted_dek_embeds_correct_creator() {
    use messaging::utils;

    let creator = @0xA11CE;
    let nonce: u256 = 42;

    let encrypted_dek = make_mock_encrypted_dek(creator, nonce);
    let identity_bytes = utils::parse_identity_bytes(&encrypted_dek);
    let (parsed_creator, parsed_nonce) = utils::unpack_identity_bytes(identity_bytes);

    assert!(parsed_creator == creator);
    assert!(parsed_nonce == nonce);
}

#[test]
fun test_make_mock_encrypted_dek_simple_works() {
    use messaging::utils;

    let creator = @0xB0B;
    let nonce_value: u64 = 999;

    let encrypted_dek = make_mock_encrypted_dek_simple(creator, nonce_value);
    let identity_bytes = utils::parse_identity_bytes(&encrypted_dek);
    let (parsed_creator, parsed_nonce) = utils::unpack_identity_bytes(identity_bytes);

    assert!(parsed_creator == creator);
    assert!(parsed_nonce == (nonce_value as u256));
}
