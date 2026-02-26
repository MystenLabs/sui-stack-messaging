// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { decodeSuiPrivateKey } from '@mysten/sui/cryptography';
import { SuiJsonRpcClient } from '@mysten/sui/jsonRpc';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { Transaction } from '@mysten/sui/transactions';

import type { IntegrationConfig } from './env-config.js';

// Permission type names matching the Move module
type MessagingPermission = 'MessagingSender' | 'MessagingReader' | 'MessagingEditor' | 'MessagingDeleter';

const ALL_PERMISSIONS: MessagingPermission[] = [
	'MessagingSender',
	'MessagingReader',
	'MessagingEditor',
	'MessagingDeleter',
];

export interface GroupSetupResult {
	groupId: string;
	adminKeypair: Ed25519Keypair;
	memberKeypair: Ed25519Keypair;
	nonMemberKeypair: Ed25519Keypair;
}

// Creates a new on-chain group, grants full permissions to a member keypair,
// and waits for the relayer to sync via gRPC events.
export async function setupTestGroup(config: IntegrationConfig): Promise<GroupSetupResult> {
	const client = new SuiJsonRpcClient({ url: config.suiRpcUrl, network: 'testnet' });

	const { secretKey } = decodeSuiPrivateKey(config.testWalletPrivateKey);
	const adminKeypair = Ed25519Keypair.fromSecretKey(secretKey);

	const memberKeypair = Ed25519Keypair.generate();
	const nonMemberKeypair = Ed25519Keypair.generate();

	// Step 1: Create group on-chain via messaging::create_and_share_group
	const createTx = new Transaction();
	const [emptyVecSet] = createTx.moveCall({
		target: '0x2::vec_set::empty',
		typeArguments: ['address'],
	});
	createTx.moveCall({
		target: `${config.messagingPackageId}::messaging::create_and_share_group`,
		arguments: [
			createTx.object(config.messagingNamespaceId),
			createTx.pure.vector('u8', Array.from(new Uint8Array(32))),
			emptyVecSet,
		],
	});
	createTx.setSender(adminKeypair.toSuiAddress());

	const createResult = await client.signAndExecuteTransaction({
		transaction: createTx,
		signer: adminKeypair,
		options: { showObjectChanges: true },
	});
	await client.waitForTransaction({ digest: createResult.digest });

	const groupObject = createResult.objectChanges?.find(
		(change) => change.type === 'created' && change.objectType?.includes('PermissionedGroup'),
	);
	if (!groupObject || groupObject.type !== 'created') {
		throw new Error('Failed to create group on-chain');
	}
	const groupId = groupObject.objectId;

	// Step 2: Grant all messaging permissions to the member keypair
	const grantTx = new Transaction();
	for (const permission of ALL_PERMISSIONS) {
		grantTx.moveCall({
			target: `${config.groupsPackageId}::permissioned_group::grant_permission`,
			typeArguments: [
				`${config.messagingPackageId}::messaging::Messaging`,
				`${config.messagingPackageId}::messaging::${permission}`,
			],
			arguments: [grantTx.object(groupId), grantTx.pure.address(memberKeypair.toSuiAddress())],
		});
	}
	grantTx.setSender(adminKeypair.toSuiAddress());

	const grantResult = await client.signAndExecuteTransaction({
		transaction: grantTx,
		signer: adminKeypair,
	});
	await client.waitForTransaction({ digest: grantResult.digest });

	// Step 3: Wait for the relayer to pick up on-chain events via gRPC
	console.log('Waiting 12s for relayer to sync on-chain permissions...');
	await new Promise((resolve) => setTimeout(resolve, 12_000));

	return { groupId, adminKeypair, memberKeypair, nonMemberKeypair };
}
