// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { TestProject } from 'vitest/node';
import { setupLocalnet } from './setup-localnet.js';
import { setupTestnet } from './setup-testnet.js';

/**
 * E2E globalSetup orchestrator.
 *
 * Delegates to localnet (testcontainers) or testnet (pre-deployed infra)
 * based on the `TEST_NETWORK` environment variable.
 *
 * - `localnet` (default): Spins up Sui localnet + relayer Docker via testcontainers.
 *   Uses mock SealClient. Fully automated, no external dependencies.
 *
 * - `testnet`: Connects to real Sui testnet, a pre-deployed relayer, and real Seal
 *   key servers. Requires env vars for package IDs, relayer URL, funded wallet, etc.
 */
export default async function setup(project: TestProject) {
	const network = (process.env.TEST_NETWORK ?? 'localnet') as 'localnet' | 'testnet';

	if (network === 'testnet') {
		await setupTestnet(project);
	} else {
		await setupLocalnet(project);
	}
}
