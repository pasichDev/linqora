<script lang="ts">
import {
    Stack,
    Space,
    SimpleGrid,

} from '@svelteuidev/core';
import CpuCard from '../components/home_widgets/CPUCard.svelte';
import RamCard from '../components/home_widgets/RAMCard.svelte';
import LoadingApp from '../components/LoadingApp.svelte';

import {
    FetchSystemInfo
} from "../../wailsjs/go/main/App";
import {
    onMount
} from 'svelte';
import {
    cpu,
    ram,
    systeminfo
} from 'wailsjs/go/models';

let systemInfo: systeminfo.SystemInfoInitial | null = null;
let CpuMetrics: cpu.CpuMetrics[] | null = [];
let RamMetrics: ram.RamMetrics[] | null = [];

onMount(async () => {
    systemInfo = await FetchSystemInfo();
    window.runtime.EventsOn("metrics-update", (data) => {
        CpuMetrics = data.cpuMetrics;
        RamMetrics = data.ramMetrics;
    });
});
</script>

{#if systemInfo}
<Stack align="strech" >
    <Space/>
        <SimpleGrid  breakpoints={[{ minWidth: 750, cols: 3, spacing: 'xl' }]} >

            <CpuCard cpuInfo={systemInfo.cpu_info} cpuMetrics={CpuMetrics} />

            <RamCard
                ramInfo={systemInfo.ram_info}
                metricInfo={RamMetrics}

                />

                </SimpleGrid>

                </Stack>
                {:else}
                <LoadingApp />

                {/if}
