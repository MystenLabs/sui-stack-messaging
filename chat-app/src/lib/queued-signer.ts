import {
  CurrentAccountSigner,
  type DAppKit,
  type RegisteredDAppKit,
} from '@mysten/dapp-kit-core';

/**
 * CurrentAccountSigner that serializes personal-message signs. dApp Kit does not
 * queue wallet requests, and the devstack dev-wallet — like some real wallets —
 * rejects a second concurrent sign with "a signing request is already pending".
 * Both the Seal session-key ceremony (SessionKey.getCertificate) and relayer
 * request signing go through this signer, so chaining here keeps at most one
 * sign in flight.
 */
export class QueuedCurrentAccountSigner extends CurrentAccountSigner {
  #chain: Promise<unknown> = Promise.resolve();

  // Upstream types the parameter as bare `DAppKit`, whose default generics fix
  // `networks` to `[]` — accept the app's registered instance type instead.
  constructor(dAppKit: RegisteredDAppKit) {
    super(dAppKit as unknown as DAppKit);
  }

  override signPersonalMessage(
    bytes: Uint8Array,
  ): ReturnType<CurrentAccountSigner['signPersonalMessage']> {
    const run = this.#chain.then(() => super.signPersonalMessage(bytes));
    this.#chain = run.catch(() => undefined);
    return run;
  }
}
