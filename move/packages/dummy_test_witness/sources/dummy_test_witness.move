/// Module: dummy_test_witness
/// A minimal module for testing permissioned groups with a witness type.
module dummy_test_witness::dummy_test_witness;

use permissioned_groups::permissioned_group::{Self, PermissionedGroup};

/// Witness type for testing permissioned groups.
/// Uses PascalCase to avoid One-Time Witness convention (which requires ALL_CAPS matching module name).
public struct DummyTestWitness() has drop;

/// Creates a new PermissionedGroup scoped to DummyTestWitness.
/// This function ensures the dependency on permissioned_groups is actually used.
public fun create_group(ctx: &mut TxContext): PermissionedGroup<DummyTestWitness> {
    permissioned_group::new<DummyTestWitness>(DummyTestWitness(), ctx)
}
