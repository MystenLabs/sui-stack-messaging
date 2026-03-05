// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Integration tests for HTTPRelayerTransport.
//
// These tests hit a REAL relayer server and require:
// 1. A running relayer at RELAYER_URL (default: http://localhost:3000)
// 2. Environment variables for on-chain config (see helpers/env-config.ts)
// 3. A funded Sui testnet wallet (TEST_WALLET_PRIVATE_KEY)
//
// If any requirement is missing, all tests are skipped gracefully.
//
// Run:  pnpm test:integration

import { beforeAll, describe, expect, it } from 'vitest';

import { HTTPRelayerTransport } from '../../src/relayer/http-transport.js';
import { RelayerTransportError } from '../../src/relayer/types.js';
import { isIntegrationConfigComplete, loadIntegrationConfig } from './helpers/env-config.js';
import { isRelayerReachable } from './helpers/relayer-health.js';
import { setupTestGroup } from './helpers/setup-group.js';
import type { GroupSetupResult } from './helpers/setup-group.js';

function randomNonce(): Uint8Array {
	return crypto.getRandomValues(new Uint8Array(12));
}

const config = loadIntegrationConfig();
const configComplete = isIntegrationConfigComplete(config);

describe.skipIf(!configComplete)('HTTPRelayerTransport integration', () => {
	let group: GroupSetupResult;
	let memberTransport: HTTPRelayerTransport;
	let nonMemberTransport: HTTPRelayerTransport;
	let createdMessageId: string;
	let createdNonce: Uint8Array;

	beforeAll(async () => {
		const reachable = await isRelayerReachable(config.relayerUrl);
		if (!reachable) {
			throw new Error(
				`Relayer at ${config.relayerUrl} is not reachable. Start the relayer and re-run.`,
			);
		}

		group = await setupTestGroup(config);

		memberTransport = new HTTPRelayerTransport({
			relayerUrl: config.relayerUrl,
			signer: group.memberKeypair,
		});

		nonMemberTransport = new HTTPRelayerTransport({
			relayerUrl: config.relayerUrl,
			signer: group.nonMemberKeypair,
		});
	}, 120_000);

	// sendMessage

	describe('sendMessage', () => {
		it('creates a message and returns a UUID message_id', async () => {
			createdNonce = randomNonce();
			const result = await memberTransport.sendMessage({
				groupId: group.groupId,
				encryptedText: new Uint8Array([0xca, 0xfe]),
				nonce: createdNonce,
				keyVersion: 0n,
			});

			// The relayer returns a UUID
			expect(result.messageId).toMatch(
				/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
			);
			createdMessageId = result.messageId;
		});

		it('rejects a non-member with 403', async () => {
			try {
				await nonMemberTransport.sendMessage({
					groupId: group.groupId,
					encryptedText: new Uint8Array([1]),
					nonce: randomNonce(),
					keyVersion: 0n,
				});
				expect.fail('Should have thrown RelayerTransportError');
			} catch (error) {
				expect(error).toBeInstanceOf(RelayerTransportError);
				const err = error as RelayerTransportError;
				expect(err.status).toBe(403);
			}
		});
	});

	// fetchMessage (single)

	describe('fetchMessage', () => {
		it('retrieves the message we just created with correct fields', async () => {
			const msg = await memberTransport.fetchMessage({
				messageId: createdMessageId,
				groupId: group.groupId,
			});

			expect(msg.messageId).toBe(createdMessageId);
			expect(msg.groupId).toBe(group.groupId);
			expect(msg.senderAddress).toBe(group.memberKeypair.toSuiAddress());
			expect(msg.encryptedText).toBeInstanceOf(Uint8Array);
			expect(msg.encryptedText).toEqual(new Uint8Array([0xca, 0xfe]));
			expect(msg.nonce).toBeInstanceOf(Uint8Array);
			expect(msg.nonce).toEqual(createdNonce);
			expect(msg.keyVersion).toBe(0n);
			expect(msg.isEdited).toBe(false);
			expect(msg.isDeleted).toBe(false);
			expect(msg.order).toBeGreaterThan(0);
			expect(msg.createdAt).toBeGreaterThan(0);
		});

		it('returns 404 for a non-existent message', async () => {
			try {
				await memberTransport.fetchMessage({
					messageId: '00000000-0000-0000-0000-000000000000',
					groupId: group.groupId,
				});
				expect.fail('Should have thrown');
			} catch (error) {
				expect(error).toBeInstanceOf(RelayerTransportError);
				expect((error as RelayerTransportError).status).toBe(404);
			}
		});
	});

	// fetchMessages (paginated list)

	describe('fetchMessages', () => {
		beforeAll(async () => {
			for (let i = 0; i < 3; i++) {
				await memberTransport.sendMessage({
					groupId: group.groupId,
					encryptedText: new Uint8Array([i + 1]),
					nonce: randomNonce(),
					keyVersion: 0n,
				});
			}
		}, 30_000);

		it('fetches messages with limit and hasNext', async () => {
			const result = await memberTransport.fetchMessages({
				groupId: group.groupId,
				limit: 2,
			});

			expect(result.messages.length).toBe(2);
			expect(result.hasNext).toBe(true);
			const first = result.messages[0];
			expect(first.encryptedText).toBeInstanceOf(Uint8Array);
			expect(typeof first.keyVersion).toBe('bigint');
		});

		it('paginates with afterOrder (no overlap between pages)', async () => {
			// Get first page
			const page1 = await memberTransport.fetchMessages({
				groupId: group.groupId,
				limit: 2,
			});
			const lastOrder = page1.messages[page1.messages.length - 1].order;

			// Get second page using cursor
			const page2 = await memberTransport.fetchMessages({
				groupId: group.groupId,
				afterOrder: lastOrder,
				limit: 2,
			});

			// Page 2 messages should have higher order than page 1
			expect(page2.messages[0].order).toBeGreaterThan(lastOrder);

			const page1Ids = page1.messages.map((m) => m.messageId);
			const page2Ids = page2.messages.map((m) => m.messageId);
			for (const id of page2Ids) {
				expect(page1Ids).not.toContain(id);
			}
		});
	});

	// updateMessage

	describe('updateMessage', () => {
		it('updates a message and sets isEdited to true', async () => {
			const newContent = new Uint8Array([0xbe, 0xef]);
			const updateNonce = randomNonce();

			await memberTransport.updateMessage({
				messageId: createdMessageId,
				groupId: group.groupId,
				encryptedText: newContent,
				nonce: updateNonce,
				keyVersion: 1n,
			});

			// Fetch back and verify
			const updated = await memberTransport.fetchMessage({
				messageId: createdMessageId,
				groupId: group.groupId,
			});

			expect(updated.encryptedText).toEqual(newContent);
			expect(updated.keyVersion).toBe(1n);
			expect(updated.isEdited).toBe(true);
			expect(updated.updatedAt).toBeGreaterThanOrEqual(updated.createdAt);
		});

		it('rejects update from non-member with 403', async () => {
			try {
				await nonMemberTransport.updateMessage({
					messageId: createdMessageId,
					groupId: group.groupId,
					encryptedText: new Uint8Array([0xff]),
					nonce: randomNonce(),
					keyVersion: 0n,
				});
				expect.fail('Should have thrown');
			} catch (error) {
				expect(error).toBeInstanceOf(RelayerTransportError);
				expect((error as RelayerTransportError).status).toBe(403);
			}
		});
	});

	// deleteMessage

	describe('deleteMessage', () => {
		it('soft-deletes a message and sets isDeleted to true', async () => {
			await memberTransport.deleteMessage({
				messageId: createdMessageId,
				groupId: group.groupId,
			});

			const deleted = await memberTransport.fetchMessage({
				messageId: createdMessageId,
				groupId: group.groupId,
			});

			expect(deleted.isDeleted).toBe(true);
		});
	});

	// subscribe (polling)

	describe('subscribe', () => {
		it('receives new messages via polling', async () => {
			const transport = new HTTPRelayerTransport({
				relayerUrl: config.relayerUrl,
				signer: group.memberKeypair,
				pollingIntervalMs: 500,
			});

			const controller = new AbortController();
			const received: string[] = [];

			const existing = await transport.fetchMessages({
				groupId: group.groupId,
				limit: 1,
			});
			const lastOrder =
				existing.messages.length > 0
					? existing.messages[existing.messages.length - 1].order
					: undefined;

			// Start subscribe in the background
			const subscribePromise = (async () => {
				for await (const msg of transport.subscribe({
					groupId: group.groupId,
					afterOrder: lastOrder,
					signal: controller.signal,
				})) {
					received.push(msg.messageId);
					if (received.length >= 2) {
						controller.abort();
					}
				}
			})();

			// Send 2 messages after a small delay to give subscribe time to start
			await new Promise((r) => setTimeout(r, 200));
			await memberTransport.sendMessage({
				groupId: group.groupId,
				encryptedText: new Uint8Array([0x11]),
				nonce: randomNonce(),
				keyVersion: 0n,
			});
			await memberTransport.sendMessage({
				groupId: group.groupId,
				encryptedText: new Uint8Array([0x22]),
				nonce: randomNonce(),
				keyVersion: 0n,
			});

			await subscribePromise;
			expect(received).toHaveLength(2);
		}, 30_000);
	});
});
