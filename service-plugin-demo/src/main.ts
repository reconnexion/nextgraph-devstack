import { checkEnvVar, unwrap } from './utils'
import { requestHandler, notifyHandler, updateStatus } from './handler'
import ng from '@ng-org/nextgraph';

async function main(): Promise<void> {
  checkEnvVar('NGD_PEER_ID', 'Nextgraph daemon peer id')
  checkEnvVar('PLUGIN_PRIVKEY', 'this plugin\'s peer private key (from `ngcli gen-key`)')
  await ng.init_headless({
    server_peer_id: unwrap(process.env.NGD_PEER_ID),
    client_peer_key: unwrap(process.env.PLUGIN_PRIVKEY),
    server_addr: '127.0.0.1:14400',
  })
  console.log('Register plugin...')
  const status = await ng.plugin_register('demo-plugin', requestHandler, notifyHandler)
  console.log('Done, status=', status)
  updateStatus(status)
  if (status === 'Denied') {
    console.error('The broker admin denied this plugin, giving up.')
    process.exit(1)
  }
}

main().catch((err) => {
  console.error('Failed with an uncaught exception:', err)
  process.exit(1)
})
