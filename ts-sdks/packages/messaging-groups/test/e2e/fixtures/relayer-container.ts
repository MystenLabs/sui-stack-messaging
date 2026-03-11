// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { GenericContainer, type StartedTestContainer, Wait } from 'testcontainers';

export interface RelayerContainerConfig {
	/** Sui RPC URL (e.g. http://host.testcontainers.internal:9000 for localnet) */
	suiRpcUrl: string;
	/** The permissioned-groups package ID */
	groupsPackageId: string;
	/** Port to expose on the host (default: auto-assigned) */
	hostPort?: number;
}

export interface StartedRelayer {
	container: StartedTestContainer;
	/** The relayer URL accessible from the host (e.g. http://localhost:12345) */
	url: string;
}

/**
 * Builds the relayer Docker image from the local Dockerfile and starts it.
 *
 * The relayer uses in-memory storage by default, which is ideal for testing.
 */
export async function startRelayerContainer(
	config: RelayerContainerConfig,
): Promise<StartedRelayer> {
	const RELAYER_PORT = 3000;
	const relayerDockerfilePath = '../../../relayer';

	const container = await GenericContainer.fromDockerfile(relayerDockerfilePath).build(
		'messaging-relayer-test',
		{ deleteOnExit: false },
	);

	let builder = container
		.withExposedPorts(RELAYER_PORT)
		.withEnvironment({
			PORT: String(RELAYER_PORT),
			SUI_RPC_URL: config.suiRpcUrl,
			GROUPS_PACKAGE_ID: config.groupsPackageId,
			STORAGE_TYPE: 'memory',
			MEMBERSHIP_STORE_TYPE: 'memory',
			RUST_LOG: 'messaging_relayer=debug',
		})
		.withWaitStrategy(Wait.forHttp('/health_check', RELAYER_PORT).forStatusCode(200))
		.withStartupTimeout(120_000);

	builder = builder.withLogConsumer((stream) => {
		stream.on('data', (data: Buffer) => {
			console.log(`[relayer] ${data.toString().trimEnd()}`);
		});
	});

	if (config.hostPort) {
		builder = builder.withExposedPorts({
			container: RELAYER_PORT,
			host: config.hostPort,
		});
	}

	const started = await builder.start();

	const mappedPort = started.getMappedPort(RELAYER_PORT);
	const host = started.getHost();
	const url = `http://${host}:${mappedPort}`;

	console.log(`Relayer container started at ${url}`);

	return { container: started, url };
}
