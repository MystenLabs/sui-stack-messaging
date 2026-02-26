// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0


export interface IntegrationConfig {
	relayerUrl: string;
	suiRpcUrl: string;
	groupsPackageId: string;
	messagingPackageId: string;
	messagingNamespaceId: string;
	testWalletPrivateKey: string;
}

export function loadIntegrationConfig(): IntegrationConfig {
	return {
		relayerUrl: process.env.RELAYER_URL || 'http://localhost:3000',
		suiRpcUrl: process.env.SUI_RPC_URL || 'https://fullnode.testnet.sui.io:443',
		groupsPackageId: process.env.GROUPS_PACKAGE_ID || '',
		messagingPackageId: process.env.MESSAGING_PACKAGE_ID || '',
		messagingNamespaceId: process.env.MESSAGING_NAMESPACE_ID || '',
		testWalletPrivateKey: process.env.TEST_WALLET_PRIVATE_KEY || '',
	};
}

export function isIntegrationConfigComplete(config: IntegrationConfig): boolean {
	return !!(
		config.relayerUrl &&
		config.groupsPackageId &&
		config.messagingPackageId &&
		config.messagingNamespaceId &&
		config.testWalletPrivateKey
	);
}
