function fromBase64Url(s: string): Uint8Array {
	return Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0))
		.slice(0, -1)  // drop the trailing tag byte
		.reverse()
}

export type PrivKey =
	| { Ed25519PrivKey: Uint8Array }
	| { X25519PrivKey: Uint8Array }

export type PubKey =
	| { Ed25519PubKey: Uint8Array }
	| { X25519PubKey: Uint8Array }

export function privKey(s: string): PrivKey {
	return { Ed25519PrivKey: fromBase64Url(s) }
}

export function pubKey(s: string): PubKey {
	return { Ed25519PubKey: fromBase64Url(s) }
}

export type AvailableService = {
  name: string,
  enabled: boolean,
  online: boolean,
}

export type ActivityPubConfig = {
  username: string | null, // null if not set already
  // and who knows what else
}

export type NGServiceRpcReq = {
  method: string,
  [key: string]: unknown,
}

export type NGServiceRpcResp = {
  error: string | null,
  [key: string]: unknown,
}
