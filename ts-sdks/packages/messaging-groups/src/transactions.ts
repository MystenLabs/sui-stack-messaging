// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from '@mysten/sui/transactions';

import type { MessagingGroupsCall } from './call.js';
import type {
	ArchiveGroupCallOptions,
	CreateGroupCallOptions,
	InsertGroupDataCallOptions,
	LeaveCallOptions,
	RemoveGroupDataCallOptions,
	RemoveMembersAndRotateKeyCallOptions,
	RotateEncryptionKeyCallOptions,
	SetGroupNameCallOptions,
	SetSuinsReverseLookupCallOptions,
	UnsetSuinsReverseLookupCallOptions,
} from './types.js';

export interface MessagingGroupsTransactionsOptions {
	call: MessagingGroupsCall;
}

/**
 * Transaction factory methods for messaging groups.
 *
 * Each method returns a complete Transaction object ready for signing.
 * Async thunks (from group creation, key rotation) are
 * resolved at transaction `build()` time.
 *
 * @example
 * ```ts
 * // For use with dapp-kit's signAndExecuteTransaction
 * const tx = client.messaging.tx.createAndShareGroup({
 *   name: 'My Group',
 *   initialMembers: ['0x...'],
 * });
 * signAndExecuteTransaction({ transaction: tx });
 * ```
 */
export class MessagingGroupsTransactions {
	#call: MessagingGroupsCall;

	constructor(options: MessagingGroupsTransactionsOptions) {
		this.#call = options.call;
	}

	// === Group Creation Functions ===

	/**
	 * Creates a Transaction that creates a new messaging group.
	 * Returns a tuple of (PermissionedGroup<Messaging>, EncryptionHistory).
	 */
	createGroup(options: CreateGroupCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.createGroup(options));
		return tx;
	}

	/**
	 * Creates a Transaction that creates a new messaging group and shares both objects.
	 */
	createAndShareGroup(options: CreateGroupCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.createAndShareGroup(options));
		return tx;
	}

	// === Encryption Functions ===

	/**
	 * Creates a Transaction that rotates the encryption key for a group.
	 */
	rotateEncryptionKey(options: RotateEncryptionKeyCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.rotateEncryptionKey(options));
		return tx;
	}

	/**
	 * Creates a Transaction that atomically removes members and rotates the encryption key.
	 */
	removeMembersAndRotateKey(options: RemoveMembersAndRotateKeyCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.removeMembersAndRotateKey(options));
		return tx;
	}

	// === Group Lifecycle Functions ===

	/**
	 * Creates a Transaction that permanently archives a messaging group.
	 * Requires `PermissionsAdmin` permission.
	 */
	archiveGroup(options: ArchiveGroupCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.archiveGroup(options));
		return tx;
	}

	/**
	 * Creates a Transaction that removes the sender from a messaging group.
	 */
	leave(options: LeaveCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.leave(options));
		return tx;
	}

	// === Metadata Functions ===

	/**
	 * Creates a Transaction that sets the group name.
	 * Requires `MetadataAdmin` permission.
	 */
	setGroupName(options: SetGroupNameCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.setGroupName(options));
		return tx;
	}

	/**
	 * Creates a Transaction that inserts a key-value pair into the group's metadata.
	 * Requires `MetadataAdmin` permission.
	 */
	insertGroupData(options: InsertGroupDataCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.insertGroupData(options));
		return tx;
	}

	/**
	 * Creates a Transaction that removes a key-value pair from the group's metadata.
	 * Requires `MetadataAdmin` permission.
	 */
	removeGroupData(options: RemoveGroupDataCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.removeGroupData(options));
		return tx;
	}

	// === SuiNS Reverse Lookup Functions ===

	/**
	 * Creates a Transaction that sets a SuiNS reverse lookup on a group.
	 * Requires `SuiNsAdmin` permission.
	 */
	setSuinsReverseLookup(options: SetSuinsReverseLookupCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.setSuinsReverseLookup(options));
		return tx;
	}

	/**
	 * Creates a Transaction that unsets a SuiNS reverse lookup on a group.
	 * Requires `SuiNsAdmin` permission.
	 */
	unsetSuinsReverseLookup(options: UnsetSuinsReverseLookupCallOptions): Transaction {
		const tx = new Transaction();
		tx.add(this.#call.unsetSuinsReverseLookup(options));
		return tx;
	}
}
