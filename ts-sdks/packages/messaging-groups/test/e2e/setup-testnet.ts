// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { TestProject } from 'vitest/node';

/**
 * Testnet setup: reads configuration from environment variables.
 * No testcontainers — connects to real Sui testnet, a pre-deployed relayer,
 * and real Seal key servers.
 *
 * Required environment variables:
 *   SUI_RPC_URL              — Sui testnet RPC URL (default: https://fullnode.testnet.sui.io:443)
 *   RELAYER_URL              — Pre-deployed relayer URL (e.g. http://localhost:3000)
 *   GROUPS_PACKAGE_ID        — Deployed permissioned-groups package ID
 *   MESSAGING_PACKAGE_ID     — Deployed messaging package ID
 *   MESSAGING_NAMESPACE_ID   — MessagingNamespace shared object ID
 *   MESSAGING_VERSION_ID     — Version shared object ID
 *   TEST_WALLET_PRIVATE_KEY  — Funded admin wallet (suiprivkey1...)
 *   FAUCET_URL               — Testnet faucet URL (default: https://faucet.testnet.sui.io)
 *
 * Optional:
 *   SEAL_KEY_SERVERS         — Comma-separated Seal key server object IDs
 *   SEAL_THRESHOLD           — Seal threshold (default: 2)
 */
export async function setupTestnet(project: TestProject) {
	console.log('Setting up E2E test environment (testnet)...');

	const required = (name: string): string => {
		const value = process.env[name];
		if (!value) {
			throw new Error(`Missing required env var for testnet E2E: ${name}`);
		}
		return value;
	};

	const suiRpcUrl = process.env.SUI_RPC_URL ?? 'https://fullnode.testnet.sui.io:443';
	const relayerUrl = required('RELAYER_URL');
	const groupsPackageId = required('GROUPS_PACKAGE_ID');
	const messagingPackageId = required('MESSAGING_PACKAGE_ID');
	const messagingNamespaceId = required('MESSAGING_NAMESPACE_ID');
	const messagingVersionId = required('MESSAGING_VERSION_ID');
	const adminSecretKey = required('TEST_WALLET_PRIVATE_KEY');
	const faucetUrl = process.env.FAUCET_URL ?? 'https://faucet.testnet.sui.io';

	// Parse Seal key server configs from env
	const sealKeyServerIds = (process.env.SEAL_KEY_SERVERS ?? '').split(',').filter(Boolean);
	const sealThreshold = parseInt(process.env.SEAL_THRESHOLD ?? '2', 10);
	const sealServerConfigs = sealKeyServerIds.map((objectId) => ({
		objectId,
		weight: 1,
	}));

	// Derive admin address from the private key
	const { Ed25519Keypair } = await import('@mysten/sui/keypairs/ed25519');
	const adminKeypair = Ed25519Keypair.fromSecretKey(adminSecretKey);
	const adminAddress = adminKeypair.toSuiAddress();

	project.provide('network', 'testnet');
	// Testnet doesn't use testcontainer ports — provide 0 as sentinel values
	project.provide('localnetPort', 0);
	project.provide('graphqlPort', 0);
	project.provide('faucetPort', 0);
	project.provide('suiToolsContainerId', '');
	project.provide('suiClientUrl', suiRpcUrl);
	project.provide('adminAccount', {
		secretKey: adminSecretKey,
		address: adminAddress,
	});
	project.provide('publishedPackages', {
		'permissioned-groups': { packageId: groupsPackageId, createdObjects: [] },
		messaging: { packageId: messagingPackageId, createdObjects: [] },
	});
	project.provide('messagingNamespaceId', messagingNamespaceId);
	project.provide('messagingVersionId', messagingVersionId);
	project.provide('relayerUrl', relayerUrl);
	project.provide('sealServerConfigs', sealServerConfigs);
	project.provide('faucetUrl', faucetUrl);
	project.provide('sealThreshold', sealThreshold);

	console.log(`E2E testnet environment is ready.`);
	console.log(`  Sui RPC: ${suiRpcUrl}`);
	console.log(`  Relayer: ${relayerUrl}`);
	console.log(`  Admin:   ${adminAddress}`);
}
