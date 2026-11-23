<!-- vim: expandtab ts=2 sts=2
Objective: Show case the workflow when a Nextgraph user activate and configure
the activitypub service.
-->
<script lang="ts">
  /* Init NG */
  import { init, ng } from "@ng-org/web"
  import { initNg } from "@ng-org/orm"
  import { type AvailableService } from './types'
  console.log("Init NG...")
  init((event: any) => {
    initNg(ng, event.session)
  }, true, [])

  /* List of Services */
  import ServicesList from './lib/ServicesList.svelte'
  //import { type AvailableService } from './types'
  //let apConfig: APConfig | null = $state(null)

  let services: AvailableService[] | null = $state(null)

</script>

<section id="services">
  <ServicesList bind:services={services} />
</section>
<section id="main-page">
  <p>Here soon: the rest of the shell.</p>
</section>
