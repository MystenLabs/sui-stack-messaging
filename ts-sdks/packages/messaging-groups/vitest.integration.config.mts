// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { defineConfig } from 'vitest/config';

export default defineConfig({
	test: {
		setupFiles: ['./test/setup.ts'],
		include: ['test/integration/**/*.test.ts'],
		fileParallelism: false,
		sequence: { concurrent: false },
		testTimeout: 60_000,
	},
});
