<!-- vim: expandtab ts=2 sts=2
  Widget used to communicate with the ActivityPub service.
  Display a message if the service is not available.
  If it is, display the current username or, if not yet set, offset to set it.
-->
<script lang="ts">
  import { ngSession } from '@ng-org/orm'
  import { type NGServiceRpcResp, type ActivityPubConfig } from '../types'

  async function get_config(): Promise<ActivityPubConfig> {
    console.warn("Getting ActivityPub Configuration")
    const { ng, session } = await ngSession
    const cur_config: NGServiceRpcResp = await ng.call_plugin(session.session_id, 'activitypub', { method: 'getConfig' })
    if (cur_config.error === null) {
      console.log('Got config: ', cur_config)
    } else {
      console.error('Cannot get AP config: ', cur_config.error)
    }
    return cur_config as any as ActivityPubConfig
  }

  let config_prom = get_config()
</script>

{#await config_prom}
  <p>Loading ActivityPub configuration</p>
{:then config}
  {#if config.username === null}
    <p>No username set yet.</p>
  {:else}
    <p>Username: <b>{config.username}</b></p>
  {/if}
{:catch err}
  <p>Error: {String(err)}</p>
{/await}
