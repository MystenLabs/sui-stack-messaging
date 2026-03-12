// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { MovePackageConfig } from '../../src/types.js';

/**
 * Move packages required for permissioned-groups tests.
 * Listed in dependency order (permissioned-groups must be published before example-group).
 */
export const PACKAGES: MovePackageConfig[] = [
	{
		name: 'permissioned-groups',
		moduleName: 'permissioned_group',
		localPath: 'move/packages/permissioned-groups',
		containerPath: '/test-data/permissioned-groups',
	},
	{
		name: 'example-group',
		moduleName: 'example_group',
		localPath: 'move/packages/example-group',
		containerPath: '/test-data/example-group',
	},
];
