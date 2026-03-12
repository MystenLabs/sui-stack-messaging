// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { resolve } from 'path';
import { defineConfig } from 'vitest/config';

export default defineConfig({
	resolve: {
		alias: {
			'@publish-utils': resolve(__dirname, '../../../publish/src/utils/index.ts'),
		},
	},
	test: {
		name: 'messaging-groups-e2e',
		environment: 'node',
		globalSetup: ['./test/e2e/setup.ts'],
		include: ['./test/e2e/**/*.test.ts'],
		testTimeout: 120_000,
		hookTimeout: 180_000,
		fileParallelism: false,
	},
});
