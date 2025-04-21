<script lang="ts">
import {
    Stack,
    Space,
    SimpleGrid,
    Loader

} from '@svelteuidev/core';
import CpuCard from '../components/home_widgets/CPUCard.svelte';
import RamCard from '../components/home_widgets/RAMCard.svelte';
import SpaceCard from '../components/home_widgets/SpaceCard.svelte';
import {
    FetchSystemInfo
} from "../../wailsjs/go/main/App";
import {
    onMount
} from 'svelte';
import {
    backend,
    database
} from 'wailsjs/go/models';

let systemInfo: backend.SystemInfoInitial | null = null;
let CpuMetrics: database.CpuMetrics[] | null = [];
let RamMetrics: database.RamMetrics[] | null = [];

onMount(async () => {
    systemInfo = await FetchSystemInfo();
    window.runtime.EventsOn("metrics-update", (data) => {
        CpuMetrics = data.cpuMetrics;
        RamMetrics = data.ram;
    });
});
</script>

<Stack align="strech" >
    <Space/>
        <SimpleGrid  breakpoints={[{ minWidth: 750, cols: 3, spacing: 'xl' }]} >

            {#if systemInfo}
            <CpuCard cpuInfo={systemInfo.cpu_info} cpuMetrics={CpuMetrics} />

            <RamCard
                ramInfo={systemInfo.ram_info}
                metricInfo={RamMetrics}

                />

                <SpaceCard systemDiskInfo={systemInfo.system_disk} />
                {:else}
                <Stack >   <Loader variant='dots'  size={50} />
                    <p>Завантаження...</p></Stack>

                {/if}
                </SimpleGrid>

                </Stack>
