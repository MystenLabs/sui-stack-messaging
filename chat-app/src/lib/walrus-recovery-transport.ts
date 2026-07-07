// Walrus-backed RecoveryTransport: recovers a group's archived messages when
// the relayer's store can't serve them (relayer restarted, switched, or gone).
// Reads the group's patch list from the walrus-discovery-indexer, then each
// patch's encrypted content from a Walrus aggregator; the SDK decrypts the
// results through the normal envelope-encryption path.
//
// Adapted from the SDK's reference example
// (ts-sdks/packages/sui-stack-messaging/examples/recovery-transport/).

import {
  fromWalrusMessage,
  HttpTimeoutError,
  type FetchMessagesResult,
  type RecoverMessagesParams,
  type RecoveryTransport,
  type RelayerMessage,
  type WalrusMessageWire,
} from '@mysten/sui-stack-messaging';

const DEFAULT_TIMEOUT = 30_000;

export interface WalrusRecoveryConfig {
  /** walrus-discovery-indexer REST API base URL. */
  indexerUrl: string;
  /** Walrus aggregator base URL (same one the attachments adapter uses). */
  aggregatorUrl: string;
  fetch?: typeof globalThis.fetch;
  timeout?: number;
  onError?: (error: Error) => void;
}

/** Response from GET /v1/groups/:groupId/patches on the discovery indexer. */
interface IndexerPatchesResponse {
  groupId: string;
  count: number;
  hasMore: boolean;
  patches: IndexerPatch[];
}

interface IndexerPatch {
  identifier: string;
  messageId: string;
  groupId: string;
  senderAddress: string;
  syncStatus: string;
  blobId: string;
  order: number | null;
  checkpoint: string;
}

/** A patch entry from the Walrus aggregator's quilt patches list. */
interface AggregatorPatchInfo {
  identifier: string;
  patch_id: string;
}

const bytesToHex = (bytes: number[]) =>
  bytes.map((b) => b.toString(16).padStart(2, '0')).join('');

/**
 * The relayer archives `signature`/`public_key` as byte arrays (Rust Vec<u8>),
 * but sender verification expects hex strings. Normalize before handing the
 * wire to `fromWalrusMessage` — the published SDK (<= 0.0.2) passes these
 * fields through verbatim; drop this once the SDK's own normalization ships.
 */
function normalizeSignatureFields(wire: WalrusMessageWire): WalrusMessageWire {
  const norm = (v: unknown) => (Array.isArray(v) ? bytesToHex(v as number[]) : v);
  return {
    ...wire,
    signature: norm(wire.signature) as WalrusMessageWire['signature'],
    public_key: norm(wire.public_key) as WalrusMessageWire['public_key'],
  };
}

export class WalrusRecoveryTransport implements RecoveryTransport {
  readonly #indexerUrl: string;
  readonly #aggregatorUrl: string;
  readonly #fetch: typeof globalThis.fetch;
  readonly #timeout: number;
  readonly #onError?: (error: Error) => void;

  constructor(config: WalrusRecoveryConfig) {
    this.#indexerUrl = config.indexerUrl.replace(/\/+$/, '');
    this.#aggregatorUrl = config.aggregatorUrl.replace(/\/+$/, '');
    this.#fetch = config.fetch ?? globalThis.fetch;
    this.#timeout = config.timeout ?? DEFAULT_TIMEOUT;
    this.#onError = config.onError;
  }

  async recoverMessages(params: RecoverMessagesParams): Promise<FetchMessagesResult> {
    const queryParams = new URLSearchParams();
    if (params.limit !== undefined) queryParams.set('limit', params.limit.toString());
    if (params.afterOrder !== undefined) {
      queryParams.set('after_order', params.afterOrder.toString());
    }
    if (params.beforeOrder !== undefined) {
      queryParams.set('before_order', params.beforeOrder.toString());
    }

    const queryString = queryParams.toString();
    const url = `${this.#indexerUrl}/v1/groups/${params.groupId}/patches${queryString ? `?${queryString}` : ''}`;

    const indexerResponse = await this.#request<IndexerPatchesResponse>(url);

    // Deleted messages archive a tombstone patch; skip them.
    const activePatches = indexerResponse.patches.filter(
      (p) => p.syncStatus !== 'DELETED' && p.syncStatus !== 'DELETE_PENDING',
    );
    if (activePatches.length === 0) {
      return { messages: [], hasNext: indexerResponse.hasMore };
    }

    // Group by blobId so each quilt's patch list is fetched once.
    const patchesByBlob = new Map<string, IndexerPatch[]>();
    for (const patch of activePatches) {
      const existing = patchesByBlob.get(patch.blobId);
      if (existing) existing.push(patch);
      else patchesByBlob.set(patch.blobId, [patch]);
    }

    const messages: RelayerMessage[] = [];

    for (const [blobId, patches] of patchesByBlob) {
      try {
        const allBlobPatches = await this.#request<AggregatorPatchInfo[]>(
          `${this.#aggregatorUrl}/v1/quilts/${blobId}/patches`,
        );
        const identifierToPatchId = new Map(
          allBlobPatches.map((bp) => [bp.identifier, bp.patch_id]),
        );

        for (const patch of patches) {
          const patchId = identifierToPatchId.get(patch.identifier);
          if (!patchId) {
            this.#onError?.(
              new Error(`No patch ID found for ${patch.identifier} in blob ${blobId}`),
            );
            continue;
          }

          try {
            const patchResponse = await this.#fetch(
              `${this.#aggregatorUrl}/v1/blobs/by-quilt-patch-id/${patchId}`,
              { signal: AbortSignal.timeout(this.#timeout) },
            );
            if (!patchResponse.ok) {
              throw new Error(`Aggregator returned ${patchResponse.status} for patch ${patchId}`);
            }
            const wire = JSON.parse(await patchResponse.text()) as WalrusMessageWire;
            messages.push(fromWalrusMessage(normalizeSignatureFields(wire)));
          } catch (err) {
            this.#onError?.(
              new Error(`Failed to read patch ${patchId} from blob ${blobId}`, { cause: err }),
            );
          }
        }
      } catch (err) {
        this.#onError?.(new Error(`Failed to read blob ${blobId} from Walrus`, { cause: err }));
      }
    }

    messages.sort((a, b) => a.order - b.order);
    return { messages, hasNext: indexerResponse.hasMore };
  }

  async #request<T>(url: string): Promise<T> {
    try {
      const response = await this.#fetch(url, { signal: AbortSignal.timeout(this.#timeout) });
      if (!response.ok) {
        const body = await response.text().catch(() => '');
        const error = new Error(
          `Request failed: ${response.status} ${response.statusText}${body ? ` — ${body}` : ''}`,
        );
        this.#onError?.(error);
        throw error;
      }
      return (await response.json()) as T;
    } catch (error) {
      if (error instanceof Error && error.name === 'TimeoutError') {
        const timeoutError = new HttpTimeoutError(url, this.#timeout);
        this.#onError?.(timeoutError);
        throw timeoutError;
      }
      if (error instanceof Error) this.#onError?.(error);
      throw error;
    }
  }
}
