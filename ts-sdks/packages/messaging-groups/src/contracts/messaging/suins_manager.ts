/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/

/**
 * Module: suins_manager
 *
 * Actor object that allows authorized callers to set/unset SuiNS reverse lookups
 * on `PermissionedGroup<T>` objects.
 *
 * `SuinsManager` is a derived singleton object from `MessagingNamespace`. It is
 * granted `ObjectAdmin` on every group created via `messaging::create_group`, and
 * exposes `set_reverse_lookup` / `unset_reverse_lookup` functions that call
 * `object_uid_mut` on the group to obtain a `&mut UID` for the SuiNS controller.
 *
 * This module does NOT import `messaging.move` to avoid a circular dependency. The
 * generic functions are instantiated with the concrete `Messaging` type at the
 * call site in `messaging.move`.
 *
 * All public entry points are in the `messaging` module:
 *
 * - `messaging::set_suins_reverse_lookup`
 * - `messaging::unset_suins_reverse_lookup`
 */

import { MoveStruct } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
const $moduleName = '@local-pkg/messaging::suins_manager';
export const SuinsManager = new MoveStruct({
	name: `${$moduleName}::SuinsManager`,
	fields: {
		id: bcs.Address,
	},
});
