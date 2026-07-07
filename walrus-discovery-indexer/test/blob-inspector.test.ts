import { describe, it, expect, vi } from 'vitest';
import { makeAggregatorInspector } from '../src/blob-inspector.js';

const AGGREGATOR = 'http://aggregator.local:9185';
const BLOB_ID = 'HXP1wtbzpOfL-mRHsZuQlbYMXBL-QeirJXo4GY1wMfQ';

function fetchReturning(status: number, body?: unknown): typeof fetch {
  return vi.fn(async () =>
    new Response(body === undefined ? null : JSON.stringify(body), { status }),
  ) as unknown as typeof fetch;
}

describe('makeAggregatorInspector', () => {
  it('maps aggregator patch entries to DiscoveredPatch', async () => {
    const fetchFn = fetchReturning(200, [
      {
        identifier: 'msg-9014f8f5-521f-4b4a-aaf5-8d300ea087d4',
        patch_id: `${BLOB_ID}BBAAWAA`,
        tags: {
          source: 'sui-messaging-relayer',
          group_id: '0xgroup',
          sender: '0xsender',
          sync_status: 'SYNCED',
          order: '3',
        },
      },
    ]);

    const inspect = makeAggregatorInspector(AGGREGATOR, fetchFn);
    const discovery = await inspect(BLOB_ID, 42n);

    expect(fetchFn).toHaveBeenCalledWith(`${AGGREGATOR}/v1/quilts/${BLOB_ID}/patches`);
    expect(discovery).not.toBeNull();
    expect(discovery!.blobId).toBe(BLOB_ID);
    expect(discovery!.checkpoint).toBe(42n);
    expect(discovery!.patches).toEqual([
      {
        identifier: 'msg-9014f8f5-521f-4b4a-aaf5-8d300ea087d4',
        messageId: '9014f8f5-521f-4b4a-aaf5-8d300ea087d4',
        groupId: '0xgroup',
        senderAddress: '0xsender',
        syncStatus: 'SYNCED',
        blobId: BLOB_ID,
        order: 3,
        checkpoint: '42',
      },
    ]);
  });

  it('filters out patches from other sources and non-message identifiers', async () => {
    const fetchFn = fetchReturning(200, [
      { identifier: 'msg-1', tags: { source: 'someone-else' } },
      { identifier: 'not-a-message', tags: { source: 'sui-messaging-relayer' } },
      { identifier: 'msg-2', tags: { source: 'sui-messaging-relayer' } },
    ]);

    const inspect = makeAggregatorInspector(AGGREGATOR, fetchFn);
    const discovery = await inspect(BLOB_ID, 1n);

    expect(discovery!.patches).toHaveLength(1);
    expect(discovery!.patches[0].messageId).toBe('2');
  });

  it('returns null when no patches match', async () => {
    const fetchFn = fetchReturning(200, [
      { identifier: 'msg-1', tags: { source: 'someone-else' } },
    ]);
    const inspect = makeAggregatorInspector(AGGREGATOR, fetchFn);
    expect(await inspect(BLOB_ID, 1n)).toBeNull();
  });

  it('returns null on non-quilt blobs (aggregator 4xx)', async () => {
    const inspect = makeAggregatorInspector(AGGREGATOR, fetchReturning(400));
    expect(await inspect(BLOB_ID, 1n)).toBeNull();
  });

  it('returns null on fetch errors without throwing', async () => {
    const fetchFn = vi.fn(async () => {
      throw new Error('connection refused');
    }) as unknown as typeof fetch;
    const inspect = makeAggregatorInspector(AGGREGATOR, fetchFn);
    expect(await inspect(BLOB_ID, 1n)).toBeNull();
  });

  it('tolerates missing tags and order', async () => {
    const fetchFn = fetchReturning(200, [
      { identifier: 'msg-x', tags: { source: 'sui-messaging-relayer' } },
    ]);
    const inspect = makeAggregatorInspector(AGGREGATOR, fetchFn);
    const discovery = await inspect(BLOB_ID, 1n);
    expect(discovery!.patches[0]).toMatchObject({
      messageId: 'x',
      groupId: '',
      senderAddress: '',
      syncStatus: '',
      order: null,
    });
  });
});
