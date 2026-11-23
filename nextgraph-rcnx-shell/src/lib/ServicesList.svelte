<!-- vim: expandtab ts=2 sts=2
  Get the list of available services and display it as a menu with a toggle to
  enable/disable, as well as a link to edit the configuration if the service is
  known.
-->
<script lang="ts">
  import { ngSession } from '@ng-org/orm'
  import { type AvailableService } from '../types'

  let { services = $bindable() } = $props()

  async function fetch_services() {
    console.log("Fetching services")
    const { ng, session } = await ngSession
    const srvs: AvailableService[] = await ng.list_services(session.session_id)
    console.log("Services: ", srvs)
    services = srvs  // triggers parent
    return srvs
  }

  /* Fetch at startup, and refetch whenever services is reset to null: */
  let services_prom = $derived(
    services === null ? fetch_services() : Promise.resolve(services))
</script>

{#await services_prom}
  <p>Loading list of services…</p>
{:then srvs}
  {#if srvs.length === 0}
    <p class="text-base-content/60 italic">No service found on this broker.</p>
  {:else}
    <div class="flex items-center gap-2 text-base-content/60">
      Got {srvs.length} service{#if srvs.length > 1}s{/if}.
    </div>
  {/if}
{:catch err}
  <div role="alert" class="alert alert-error">
    <span>Error: {String(err)}</span>
  </div>
{/await}
