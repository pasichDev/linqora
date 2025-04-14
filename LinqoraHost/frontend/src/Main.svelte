<script>
import {
    Space,
    Stack,
    Divider

} from '@svelteuidev/core';
import {
    onMount
} from 'svelte';
import {
    GetSystemInfo
} from "../wailsjs/go/main/SystemInfoInitial";
import CpuCard from './components/CPUCard.svelte';
import SpaceCard from './components/SpaceCard.svelte';
import RamCard from './components/RAMCard.svelte';

let systemInfo = {
    system: '',
    cpu: '',
    ram_total: '',
    ram_usage: '',
};

const getSystemInfo = async () => {
    try {
        console.log('Fetching system info...');
        const info = await GetSystemInfo();
        console.log('Fetched info:', info);
        if (info && info.system && info.cpu && info.ram_total && info.ram_usage) {
            systemInfo = {
                ...info
            };
        } else {
            console.error('Invalid data format:', info);
        }
    } catch (err) {
        console.error('Error fetching system info:', err);
    }
};

onMount(() => {
    console.log('onMount triggered');
    getSystemInfo();
});
</script>

<Stack align="strech">

    <CpuCard
        valueAtribute = "33%"
        atribute={systemInfo.cpu}/>
        <Divider  color="dark" />
        <RamCard
            usage = {systemInfo.ram_usage}
            total = {systemInfo.ram_total}/>
            <Divider color="dark" />
            <SpaceCard
                />

                </Stack>
