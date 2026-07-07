import type { WalrusClient } from '@mysten/walrus';
import type { DiscoveryEvent, DiscoveredPatch } from './types.js';
import { MSG_PREFIX, SOURCE_TAG } from './constants.js';

/** How the checkpoint listener inspects a certified blob — either the
 *  @mysten/walrus SDK path (inspectBlob) or the aggregator HTTP path
 *  (makeAggregatorInspector). */
export type BlobInspector = (blobId: string, checkpoint: bigint) => Promise<DiscoveryEvent | null>;

// Inspect a Walrus blob for messaging patches using quilt index tags.
export async function inspectBlob(
  walrusClient: WalrusClient,
  blobId: string,
  checkpoint: bigint,
): Promise<DiscoveryEvent | null> {
  try {
    const blob = await walrusClient.getBlob({ blobId });

    // Filter by source tag - only returns patches from this relayer
    const files = await blob.files({ tags: [{ source: SOURCE_TAG }] });
    if (files.length === 0) return null;

    const patches = [];
    for (const file of files) {
      try {
        const identifier = await file.getIdentifier();
        if (!identifier?.startsWith(MSG_PREFIX)) continue;

        // Read metadata from quilt index tags (no content fetch needed)
        const tags = await file.getTags();

        patches.push({
          identifier,
          messageId: identifier.replace(MSG_PREFIX, ''),
          groupId: tags.group_id ?? '',
          senderAddress: tags.sender ?? '',
          syncStatus: tags.sync_status ?? '',
          blobId,
          order: tags.order ? parseInt(tags.order, 10) : null,
          checkpoint: checkpoint.toString(),
        });
      } catch {
        console.warn(`Failed to read tags for patch in blob ${blobId}`);
      }
    }

    if (patches.length === 0) return null;

    return {
      blobId,
      checkpoint,
      discoveredAt: new Date().toISOString(),
      patches,
    };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    if (!msg.includes('Unsupported quilt version')) {
      console.warn(`Failed to inspect blob ${blobId}: ${msg}`);
    }
    return null;
  }
}

interface AggregatorPatchEntry {
  identifier?: string;
  patch_id?: string;
  tags?: Record<string, string>;
}

/** Aggregator-HTTP inspection: reads the quilt index via
 *  GET {aggregatorUrl}/v1/quilts/{blobId}/patches, which carries the same
 *  identifiers + tags the SDK path reads from the quilt index. Used when the
 *  storage nodes are not directly reachable (a local devstack cluster's
 *  committee hostnames only resolve inside its Docker network); works against
 *  any aggregator. Non-quilt blobs 4xx and are skipped, mirroring the SDK
 *  path's "Unsupported quilt version" skip. */
export function makeAggregatorInspector(
  aggregatorUrl: string,
  fetchFn: typeof fetch = fetch,
): BlobInspector {
  return async (blobId, checkpoint) => {
    try {
      const res = await fetchFn(`${aggregatorUrl}/v1/quilts/${blobId}/patches`);
      if (!res.ok) return null;

      const entries = (await res.json()) as AggregatorPatchEntry[];
      if (!Array.isArray(entries)) return null;

      const patches: DiscoveredPatch[] = [];
      for (const entry of entries) {
        const identifier = entry.identifier;
        const tags = entry.tags ?? {};
        if (!identifier?.startsWith(MSG_PREFIX)) continue;
        if (tags.source !== SOURCE_TAG) continue;

        patches.push({
          identifier,
          messageId: identifier.replace(MSG_PREFIX, ''),
          groupId: tags.group_id ?? '',
          senderAddress: tags.sender ?? '',
          syncStatus: tags.sync_status ?? '',
          blobId,
          order: tags.order ? parseInt(tags.order, 10) : null,
          checkpoint: checkpoint.toString(),
        });
      }

      if (patches.length === 0) return null;

      return {
        blobId,
        checkpoint,
        discoveredAt: new Date().toISOString(),
        patches,
      };
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      console.warn(`Failed to inspect blob ${blobId} via aggregator: ${msg}`);
      return null;
    }
  };
}
