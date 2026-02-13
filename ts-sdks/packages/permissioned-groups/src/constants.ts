// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { PermissionedGroupsPackageConfig } from './types.js';

export const TESTNET_PERMISSIONED_GROUPS_PACKAGE_CONFIG = {
	packageId: '0xTBD',
} satisfies PermissionedGroupsPackageConfig;

export const MAINNET_PERMISSIONED_GROUPS_PACKAGE_CONFIG = {
	packageId: '0xTBD',
} satisfies PermissionedGroupsPackageConfig;

/**
 * The derivation key used to derive the PermissionsTable from a PermissionedGroup.
 * Must match the Move constant `PERMISSIONS_TABLE_DERIVATION_KEY_BYTES` in `permissioned_group.move`.
 */
export const PERMISSIONS_TABLE_DERIVATION_KEY = 'permissions_table';

// === Internal SuiNS Configuration ===

/** @internal SuiNS config for testnet. */
export const TESTNET_SUINS_CONFIG = {
	packageId: '0x22fa05f21b1ad71442491220bb9338f7b7095fe35000ef88d5400d28523bdd93',
	suinsObjectId: '0x300369e8909b9a6464da265b9a5a9ab6fe2158a040e84e808628cde7a07ee5a3',
} as const;

/** @internal SuiNS config for mainnet. */
export const MAINNET_SUINS_CONFIG = {
	packageId: '0xd22b24490e0bae52676651b4f56660a5ff8022a2576e0089f79b3c88d44e08f0',
	suinsObjectId: '0x6e0ddefc0ad98889c04bab9639e512c21766c5e6366f89e696956d9be6952871',
} as const;

/** @internal Type for SuiNS configuration. */
export type SuinsConfig = {
	packageId: string;
	suinsObjectId: string;
};

/**
 * Returns full Move type paths for all core permissions defined in the permissioned-groups package.
 *
 * @example
 * ```ts
 * const perms = permissionTypes('0xabc...');
 * // perms.PermissionsAdmin === '0xabc...::permissioned_group::PermissionsAdmin'
 *
 * await client.groups.grantPermission({
 *   groupId, member, signer,
 *   permissionType: perms.PermissionsAdmin,
 * });
 * ```
 */
export function permissionTypes(packageId: string) {
	return {
		PermissionsAdmin: `${packageId}::permissioned_group::PermissionsAdmin`,
		ExtensionPermissionsAdmin: `${packageId}::permissioned_group::ExtensionPermissionsAdmin`,
		ObjectAdmin: `${packageId}::permissioned_group::ObjectAdmin`,
	} as const;
}

/**
 * Returns the full Move type name for `PermissionedGroup<T>`.
 *
 * @param packageId - The permissioned-groups package ID
 * @param witnessType - The witness type parameter (e.g., `0xdef::messaging::Messaging`)
 */
export function permissionedGroupType(packageId: string, witnessType: string): string {
	return `${packageId}::permissioned_group::PermissionedGroup<${witnessType}>`;
}
