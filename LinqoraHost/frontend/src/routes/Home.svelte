<script lang="ts">
import {
    Stack,
    Divider

} from '@svelteuidev/core';
import CpuCard from '.././components/CPUCard.svelte';
import RamCard from '.././components/RAMCard.svelte';
import SpaceCard from '.././components/SpaceCard.svelte';
import {
    FetchSystemInfo
} from "../../wailsjs/go/main/App";
import {
    onMount
} from 'svelte';
import {
    backend, database
} from 'wailsjs/go/models';

let systemInfo: backend.SystemInfoInitial | null = null;
let CpuMetrics: database.CpuMetrics[] | null = [];

onMount(async () => {
    systemInfo = await FetchSystemInfo();
    window.runtime.EventsOn("metrics-update", (data) => {
      CpuMetrics = data.cpuMetrics;
      ram = data.ram;
    });
});



  let cpu = {};
  let ram = {};


</script>

<Stack align="strech" >
    {#if systemInfo}
    <CpuCard cpuInfo={systemInfo.cpu_info} cpuMetrics={CpuMetrics} />
    <Divider color="dark" />
    <RamCard
        usage={ram.usage?.toFixed(1)}
        total = {systemInfo.ram_info.total}
        usagePercentage =  {ram.loadPercent?.toFixed(1)}
      />
    <Divider color="dark" />
    <SpaceCard systemDiskInfo={systemInfo.system_disk} />
    {:else}
    <p>Завантаження...</p>
    {/if}

</Stack>
