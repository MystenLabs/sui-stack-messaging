// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { MovePackageConfig } from '../../src/types.js';

/**
 * Move packages required for example-apps tests.
 * Listed in dependency order (example_app depends on messaging and permissioned-groups).
 */
export const PACKAGES: MovePackageConfig[] = [
	{
		name: 'permissioned-groups',
		moduleName: 'permissioned_group',
		localPath: 'move/packages/permissioned-groups',
		containerPath: '/test-data/permissioned-groups',
	},
	{
		name: 'messaging',
		moduleName: 'messaging',
		localPath: 'move/packages/messaging',
		containerPath: '/test-data/messaging',
	},
	{
		name: 'example-app',
		moduleName: 'custom_seal_policy',
		localPath: 'move/packages/example_app',
		containerPath: '/test-data/example_app',
	},
];
