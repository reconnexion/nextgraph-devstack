// Print the peer-id of the ngd broker at $NGD_URL (default http://127.0.0.1:14400),
// waiting for it to answer.
//
// The peer-id is read from the broker's /.ng_bootstrap, where it comes as the
// raw bytes of an Ed25519 PubKey. Its string form (as ngd logs it) is the
// base64url of its serde_bare serialization (variant tag 0 then the 32 bytes),
// reversed.

const url = (process.env.NGD_URL ?? 'http://127.0.0.1:14400') + '/.ng_bootstrap'
const retryDelayMs = 2000
const maxTries = 60

async function fetchPeerId() {
  const resp = await fetch(url)
  if (!resp.ok) throw new Error(`${url}: HTTP ${resp.status}`)
  const js = await resp.json()
  const bytes = js.V0.bootstrap.servers[0].peer_id.Ed25519PubKey
  if (bytes?.length !== 32) throw new Error(`${url}: unexpected peer_id in ${JSON.stringify(js)}`)
  return Buffer.from([0, ...bytes].reverse()).toString('base64url')
}

for (let i = 1; ; i++) {
  try {
    console.log(await fetchPeerId())
    break
  } catch (err) {
    if (i >= maxTries) {
      console.error('Cannot get ngd peer-id:', err)
      process.exit(1)
    }
    console.error(`Waiting for ngd (${err.cause?.code ?? err.message})...`)
    await new Promise((resolve) => setTimeout(resolve, retryDelayMs))
  }
}
