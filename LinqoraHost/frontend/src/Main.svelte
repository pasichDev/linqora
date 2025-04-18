<script lang="ts">
import {
    Stack,
    Divider

} from '@svelteuidev/core';
import CpuCard from './components/CPUCard.svelte';
import RamCard from './components/RAMCard.svelte';
import SpaceCard from './components/SpaceCard.svelte';
import {
    FetchSystemInfo
} from "../wailsjs/go/main/App";
import {
    onMount
} from 'svelte';
import {
    backend
} from 'wailsjs/go/models';

let systemInfo: backend.SystemInfoInitial | null = null;

onMount(async () => {
    systemInfo = await FetchSystemInfo();
});



  let cpu = {};
  let ram = {};

  onMount(() => {
    window.runtime.EventsOn("metrics-update", (data) => {
      cpu = data.cpu;
      ram = data.ram;
    });
  });

</script>

<Stack align="strech" >

<h2>CPU Metric</h2>
<ul>
  <li>Temperature: {cpu.temperature?.toFixed(1)}°C</li>
  <li>Load: {cpu.loadPercent?.toFixed(1)}%</li>
</ul>

    {#if systemInfo}
    <CpuCard cpuInfo={systemInfo.cpu_info} />
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
