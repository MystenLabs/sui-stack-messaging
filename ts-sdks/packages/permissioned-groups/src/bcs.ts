// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { PermissionedGroupsPackageConfig } from './types.js';

import {
	Administrator,
	ExtensionPermissionsManager,
	GroupCreated,
	GroupDerived,
	MemberAdded,
	MemberRemoved,
	PermissionedGroup,
	PermissionsGranted,
	PermissionsRevoked,
} from './contracts/permissioned_groups/permissioned_group.js';

export type ParsedPermissionedGroup = (typeof PermissionedGroup)['$inferType'];
export type ParsedAdministrator = (typeof Administrator)['$inferType'];
export type ParsedExtensionPermissionsManager = (typeof ExtensionPermissionsManager)['$inferType'];
export type ParsedGroupCreated = (typeof GroupCreated)['$inferType'];
export type ParsedGroupDerived = (typeof GroupDerived)['$inferType'];
export type ParsedMemberAdded = (typeof MemberAdded)['$inferType'];
export type ParsedMemberRemoved = (typeof MemberRemoved)['$inferType'];
export type ParsedPermissionsGranted = (typeof PermissionsGranted)['$inferType'];
export type ParsedPermissionsRevoked = (typeof PermissionsRevoked)['$inferType'];

export interface PermissionedGroupsBCSOptions {
	packageConfig: PermissionedGroupsPackageConfig;
}

/**
 * BCS type definitions for the permissioned-groups package.
 *
 * Each instance creates transformed copies of the generated BCS types
 * with the correct package ID in the type name, ensuring multiple SDK
 * instances with different package configurations don't interfere.
 *
 * @example
 * ```ts
 * const bcs = new PermissionedGroupsBCS({
 *   packageConfig: { packageId: '0x123...' }
 * });
 *
 * const group = bcs.PermissionedGroup.parse(permissionedGroupObject.content);
 * ```
 */
export class PermissionedGroupsBCS {
	/** Core permission type: super-admin role */
	readonly Administrator;
	/** Core permission type: can manage extension permissions */
	readonly ExtensionPermissionsManager;
	/** Main group struct containing membership and permission data */
	readonly PermissionedGroup;
	/** Event emitted when a group is created */
	readonly GroupCreated;
	/** Event emitted when a group is derived from a parent object */
	readonly GroupDerived;
	/** Event emitted when a member is added to a group */
	readonly MemberAdded;
	/** Event emitted when a member is removed from a group */
	readonly MemberRemoved;
	/** Event emitted when permissions are granted to a member */
	readonly PermissionsGranted;
	/** Event emitted when permissions are revoked from a member */
	readonly PermissionsRevoked;

	constructor(options: PermissionedGroupsBCSOptions) {
		const moduleName = `${options.packageConfig.packageId}::permissioned_group`;

		this.Administrator = Administrator.transform({
			name: `${moduleName}::Administrator`,
		});
		this.ExtensionPermissionsManager = ExtensionPermissionsManager.transform({
			name: `${moduleName}::ExtensionPermissionsManager`,
		});
		this.PermissionedGroup = PermissionedGroup.transform({
			name: `${moduleName}::PermissionedGroup`,
		});
		this.GroupCreated = GroupCreated.transform({
			name: `${moduleName}::GroupCreated`,
		});
		this.GroupDerived = GroupDerived.transform({
			name: `${moduleName}::GroupDerived`,
		});
		this.MemberAdded = MemberAdded.transform({
			name: `${moduleName}::MemberAdded`,
		});
		this.MemberRemoved = MemberRemoved.transform({
			name: `${moduleName}::MemberRemoved`,
		});
		this.PermissionsGranted = PermissionsGranted.transform({
			name: `${moduleName}::PermissionsGranted`,
		});
		this.PermissionsRevoked = PermissionsRevoked.transform({
			name: `${moduleName}::PermissionsRevoked`,
		});
	}
}
