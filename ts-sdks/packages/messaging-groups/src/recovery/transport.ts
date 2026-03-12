// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { FetchMessagesParams, FetchMessagesResult } from '../relayer/types.js';

/** Read-only transport for recovering messages from an alternative storage backend. */
export interface RecoveryTransport {
	recoverMessages(params: FetchMessagesParams): Promise<FetchMessagesResult>;
}
