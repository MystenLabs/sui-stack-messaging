// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { bcs } from '@mysten/sui/bcs';
import { Transaction } from '@mysten/sui/transactions';

import * as permissionedGroup from './contracts/permissioned_groups/permissioned_group.js';
import type {
	HasPermissionViewOptions,
	IsMemberViewOptions,
	PermissionedGroupsCompatibleClient,
	PermissionedGroupsPackageConfig,
} from './types.js';

export interface PermissionedGroupsViewOptions {
	packageConfig: PermissionedGroupsPackageConfig;
	witnessType: string;
	client: PermissionedGroupsCompatibleClient;
}

/**
 * View methods for querying permissioned group state.
 *
 * These methods use devInspect/dryRunTransaction to read on-chain state
 * without requiring a signature or spending gas.
 *
 * Note: Fields like `creator` and `administrators_count` are available
 * directly on the PermissionedGroup object when fetched via getObject.
 *
 * @example
 * ```ts
 * const hasPerm = await client.groups.view.hasPermission({
 *   groupId: '0x456...',
 *   member: '0x789...',
 *   permissionType: '0xabc::my_app::Editor',
 * });
 *
 * const isMember = await client.groups.view.isMember({
 *   groupId: '0x456...',
 *   member: '0x789...',
 * });
 * ```
 */
export class PermissionedGroupsView {
	#packageConfig: PermissionedGroupsPackageConfig;
	#witnessType: string;
	#client: PermissionedGroupsCompatibleClient;

	constructor(options: PermissionedGroupsViewOptions) {
		this.#packageConfig = options.packageConfig;
		this.#witnessType = options.witnessType;
		this.#client = options.client;
	}

	/**
	 * Checks if the given address has the specified permission.
	 *
	 * @param options.groupId - Object ID of the PermissionedGroup
	 * @param options.member - Address to check
	 * @param options.permissionType - The permission type to check (e.g., '0xabc::my_app::Editor')
	 * @returns `true` if the address has the permission, `false` otherwise
	 */
	async hasPermission(options: HasPermissionViewOptions): Promise<boolean> {
		const tx = new Transaction();
		tx.add(
			permissionedGroup.hasPermission({
				package: this.#packageConfig.packageId,
				arguments: {
					self: options.groupId,
					member: options.member,
				},
				typeArguments: [this.#witnessType, options.permissionType],
			}),
		);

		// TODO: Replace dryRunTransaction with simulateTransaction when available in core API.
		// devInspect is not yet available through ClientWithCoreApi.
		const result = await this.#client.core.dryRunTransaction(tx, { showResults: true });
		const returnValues = result.results?.[0]?.returnValues;
		if (!returnValues || returnValues.length === 0) {
			throw new Error('No return value from hasPermission');
		}
		const [bytes] = returnValues[0];
		return bcs.Bool.parse(Uint8Array.from(bytes));
	}

	/**
	 * Checks if the given address is a member of the group.
	 * A member is any address that has at least one permission.
	 *
	 * @param options.groupId - Object ID of the PermissionedGroup
	 * @param options.member - Address to check
	 * @returns `true` if the address is a member, `false` otherwise
	 */
	async isMember(options: IsMemberViewOptions): Promise<boolean> {
		const tx = new Transaction();
		tx.add(
			permissionedGroup.isMember({
				package: this.#packageConfig.packageId,
				arguments: {
					self: options.groupId,
					member: options.member,
				},
				typeArguments: [this.#witnessType],
			}),
		);

		// TODO: Replace dryRunTransaction with simulateTransaction when available in core API.
		const result = await this.#client.core.dryRunTransaction(tx, { showResults: true });
		const returnValues = result.results?.[0]?.returnValues;
		if (!returnValues || returnValues.length === 0) {
			throw new Error('No return value from isMember');
		}
		const [bytes] = returnValues[0];
		return bcs.Bool.parse(Uint8Array.from(bytes));
	}
}
