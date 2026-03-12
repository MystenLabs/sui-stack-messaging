// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/**
 * Raw message shape as stored on Walrus by the reference relayer.
 *
 * Uses `serde_json::to_vec()` serialization which differs from the HTTP API:
 * - `encrypted_msg` / `nonce` are number[] (not hex strings)
 * - Timestamps are ISO 8601 strings (not unix seconds)
 * - Rust field names (`id`, `sender_wallet_addr`, `encrypted_msg`)
 *
 * Pass to {@link fromWalrusMessage} to convert to {@link RelayerMessage}.
 */
export interface WalrusMessageWire {
	id: string;
	group_id: string;
	order: number | null;
	sender_wallet_addr: string;
	encrypted_msg: number[];
	nonce: number[];
	key_version: number;
	created_at: string;
	updated_at: string;
	sync_status: string;
	quilt_patch_id: string | null;
	attachments: string[];
}
