// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { RelayerMessage, SyncStatus } from '../relayer/types.js';
import type { WalrusMessageWire } from './types.js';

/**
 * Convert a raw Walrus message to the SDK's {@link RelayerMessage} format.
 *
 * Handles: number[] → Uint8Array, ISO 8601 → unix seconds,
 * Rust field names → SDK names, derives isEdited/isDeleted.
 */
export function fromWalrusMessage(wire: WalrusMessageWire): RelayerMessage {
	const createdAt = Math.floor(new Date(wire.created_at).getTime() / 1000);
	const updatedAt = Math.floor(new Date(wire.updated_at).getTime() / 1000);
	const isEdited = wire.created_at !== wire.updated_at;
	const isDeleted = wire.sync_status === 'DELETE_PENDING' || wire.sync_status === 'DELETED';

	return {
		messageId: wire.id,
		groupId: wire.group_id,
		order: wire.order ?? 0,
		encryptedText: new Uint8Array(wire.encrypted_msg),
		nonce: new Uint8Array(wire.nonce),
		keyVersion: BigInt(wire.key_version),
		senderAddress: wire.sender_wallet_addr,
		createdAt,
		updatedAt,
		attachments: [],
		isEdited,
		isDeleted,
		syncStatus: wire.sync_status as SyncStatus,
		quiltPatchId: wire.quilt_patch_id,
	};
}
