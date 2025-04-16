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
</script>

<Stack align="strech">
    {#if systemInfo}
    <CpuCard cpuInfo={systemInfo.cpu_info} />
    <Divider color="dark" />
    <RamCard
        ramInfo={systemInfo.ram_info} />
    <Divider color="dark" />
    <SpaceCard systemDiskInfo={systemInfo.system_disk} />
    {:else}
    <p>Завантаження...</p>
    {/if}

</Stack>
