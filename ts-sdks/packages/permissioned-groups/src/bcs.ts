// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { bcs, type BcsType } from '@mysten/sui/bcs';

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

export type ParsedPermissionedGroup = ReturnType<typeof PermissionedGroup>['$inferType'];
export type ParsedAdministrator = (typeof Administrator)['$inferType'];
export type ParsedExtensionPermissionsManager = (typeof ExtensionPermissionsManager)['$inferType'];
export type ParsedGroupCreated = ReturnType<typeof GroupCreated>['$inferType'];
export type ParsedGroupDerived<DerivationKey = unknown> = {
	group_id: string;
	creator: string;
	parent_id: string;
	derivation_key: DerivationKey;
};
export type ParsedMemberAdded = ReturnType<typeof MemberAdded>['$inferType'];
export type ParsedMemberRemoved = ReturnType<typeof MemberRemoved>['$inferType'];
export type ParsedPermissionsGranted = ReturnType<typeof PermissionsGranted>['$inferType'];
export type ParsedPermissionsRevoked = ReturnType<typeof PermissionsRevoked>['$inferType'];

const LOCAL_PACKAGE_ALIAS = '@local-pkg/permissioned-groups';

export interface PermissionedGroupsBCSOptions {
	packageConfig: PermissionedGroupsPackageConfig;
	witnessType: string;
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
	readonly Administrator: BcsType<ParsedAdministrator, unknown>;
	/** Core permission type: can manage extension permissions */
	readonly ExtensionPermissionsManager: BcsType<ParsedExtensionPermissionsManager, unknown>;
	/** Main group struct containing membership and permission data */
	readonly PermissionedGroup: BcsType<ParsedPermissionedGroup, unknown>;
	/** Event emitted when a group is created */
	readonly GroupCreated: BcsType<ParsedGroupCreated, unknown>;
	/** Event emitted when a member is added to a group */
	readonly MemberAdded: BcsType<ParsedMemberAdded, unknown>;
	/** Event emitted when a member is removed from a group */
	readonly MemberRemoved: BcsType<ParsedMemberRemoved, unknown>;
	/** Event emitted when permissions are granted to a member */
	readonly PermissionsGranted: BcsType<ParsedPermissionsGranted, unknown>;
	/** Event emitted when permissions are revoked from a member */
	readonly PermissionsRevoked: BcsType<ParsedPermissionsRevoked, unknown>;

	readonly #phantomWitnessBcs: BcsType<any>;
	readonly #packageId: string;

	constructor(options: PermissionedGroupsBCSOptions) {
		this.#packageId = options.packageConfig.packageId;

		// Phantom BcsType that carries the witness type name for codegen functions.
		// Phantom types don't affect serialization, so the underlying type is irrelevant.
		this.#phantomWitnessBcs = bcs.bool().transform({ name: options.witnessType });

		this.Administrator = this.#withPackageId(Administrator);
		this.ExtensionPermissionsManager = this.#withPackageId(ExtensionPermissionsManager);
		this.PermissionedGroup = this.#withPackageId(PermissionedGroup(this.#phantomWitnessBcs));
		this.GroupCreated = this.#withPackageId(GroupCreated(this.#phantomWitnessBcs));
		this.MemberAdded = this.#withPackageId(MemberAdded(this.#phantomWitnessBcs));
		this.MemberRemoved = this.#withPackageId(MemberRemoved(this.#phantomWitnessBcs));
		this.PermissionsGranted = this.#withPackageId(PermissionsGranted(this.#phantomWitnessBcs));
		this.PermissionsRevoked = this.#withPackageId(PermissionsRevoked(this.#phantomWitnessBcs));
	}

	/** Replaces the codegen local package alias with the real package ID in the BCS type name. */
	#withPackageId(type: BcsType<any>) {
		return type.transform({
			name: type.name.replace(LOCAL_PACKAGE_ALIAS, this.#packageId),
		});
	}

	/** Event emitted when a group is derived from a parent object */
	GroupDerived<DerivationKey extends BcsType<any>>(
		derivationKeyType: DerivationKey,
	): BcsType<ParsedGroupDerived<DerivationKey['$inferType']>, unknown> {
		return this.#withPackageId(GroupDerived(this.#phantomWitnessBcs, derivationKeyType));
	}
}
