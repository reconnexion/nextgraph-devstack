import { type KeyPair } from './types'
import { peerKey } from './keys'
import { checkEnvVar, unwrap } from './utils'
import { msgHandler } from './handler'
import ng from '@ng-org/nextgraph';

async function main(): Promise<void> {
  checkEnvVar('NGD_PEER_ID', 'Nextgraph daemon peer id')
  const peer_key: KeyPair = peerKey()
  console.info('My keypaid is: ', peer_key)
  await ng.init_headless({
    server_peer_id: unwrap(process.env.NGD_PEER_ID),
    client_peer_key: peer_key.private,
    server_addr: '127.0.0.1:14400',
  })
  console.log('Register plugin...')
  const status = await ng.plugin_register('demo-plugin', msgHandler)
  console.log('Done, status=', status)
  if (status === 'Denied') {
    console.error('The broker admin denied this plugin, giving up.')
    process.exit(1)
  }
}

main().catch((err) => {
  console.error('Failed with an uncaught exception:', err)
  process.exit(1)
})
