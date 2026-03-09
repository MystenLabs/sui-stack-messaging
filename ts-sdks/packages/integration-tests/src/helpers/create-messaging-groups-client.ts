// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { SealCompatibleClient } from '@mysten/seal';
import { SessionKey } from '@mysten/seal';
import {
	createMessagingGroupsClient as createClient,
	type RelayerTransport,
	type SealPolicy,
} from '@mysten/messaging-groups';
import type { SuiClientTypes } from '@mysten/sui/client';
import type { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';

import { createMockSealClient } from '../seal-mock/index.js';
import { createSuiClient, type SuiTransport } from './create-sui-client.js';

/** No-op transport for integration tests that only exercise on-chain operations. */
const noopTransport: RelayerTransport = {
	sendMessage: () => {
		throw new Error('noopTransport: sendMessage not implemented');
	},
	fetchMessages: () => {
		throw new Error('noopTransport: fetchMessages not implemented');
	},
	fetchMessage: () => {
		throw new Error('noopTransport: fetchMessage not implemented');
	},
	updateMessage: () => {
		throw new Error('noopTransport: updateMessage not implemented');
	},
	deleteMessage: () => {
		throw new Error('noopTransport: deleteMessage not implemented');
	},
	subscribe: () => {
		throw new Error('noopTransport: subscribe not implemented');
	},
	disconnect: () => {},
};

export interface CreateMessagingGroupsClientOptions<TApproveContext = void> {
	url: string;
	network: SuiClientTypes.Network;
	transport?: SuiTransport;
	permissionedGroupsPackageId: string;
	messagingPackageId: string;
	namespaceId: string;
	versionId: string;
	keypair: Ed25519Keypair;
	sealPolicy?: SealPolicy<TApproveContext>;
}

/**
 * Creates a fully extended Sui client with `permissionedGroups`, mock `seal`,
 * and `messagingGroups` extensions.
 *
 * Delegates to the production {@link createClient} factory, passing a mock
 * `SealClient` instance (instead of real key server configs) for localnet testing.
 *
 * Transport-agnostic: uses `SUI_TRANSPORT` env var or explicit `transport` option
 * to choose between JSON-RPC and gRPC.
 */
export function createMessagingGroupsClient<TApproveContext = void>(
	options: CreateMessagingGroupsClientOptions<TApproveContext>,
) {
	const {
		url,
		network,
		transport,
		permissionedGroupsPackageId,
		messagingPackageId,
		namespaceId,
		versionId,
		keypair,
		sealPolicy,
	} = options;

	const baseClient = createSuiClient({
		url,
		network,
		transport,
		mvr: {
			overrides: {
				packages: {
					'@local-pkg/permissioned-groups': permissionedGroupsPackageId,
					'@local-pkg/messaging': messagingPackageId,
				},
			},
		},
	});

	return createClient<TApproveContext>(baseClient, {
		seal: createMockSealClient({ suiClient: baseClient, packageId: messagingPackageId }),
		encryption: {
			sessionKey: {
				getSessionKey: () =>
					SessionKey.import(
						{
							address: keypair.getPublicKey().toSuiAddress(),
							packageId: messagingPackageId,
							creationTimeMs: Date.now(),
							ttlMin: 30,
							sessionKey: keypair.getSecretKey(),
						},
						{} as SealCompatibleClient,
					),
			},
			sealPolicy,
		},
		relayer: { transport: noopTransport },
		packageConfig: {
			messaging: {
				originalPackageId: messagingPackageId,
				latestPackageId: messagingPackageId,
				namespaceId,
				versionId,
			},
			permissionedGroups: {
				originalPackageId: permissionedGroupsPackageId,
				latestPackageId: permissionedGroupsPackageId,
			},
		},
	});
}

/** Convenience type for the return value of `createMessagingGroupsClient` with default (void) approve context. */
export type MessagingGroupsTestClient = ReturnType<typeof createMessagingGroupsClient<void>>;
