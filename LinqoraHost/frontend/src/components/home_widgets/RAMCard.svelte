<script lang="ts">
import {
    Space,
    Badge,
    Card,
    Group,
    Skeleton,
    Text
} from '@svelteuidev/core';
import {
    ram,
    systeminfo
} from 'wailsjs/go/models';

    import RamChart from '../charts/RAMChart.svelte';


export let ramInfo: systeminfo.RamInfo | null = null;
export let metricInfo: ram.RAMMetrics[] | null = null;

let lastMetrics: ram.RAMMetrics | null;

$: {
    if (metricInfo.length > 0) {
        lastMetrics = metricInfo.reverse()[metricInfo.length - 1]; 
    } else {
        lastMetrics = null; 
    }
}
</script>
<Card shadow='sm' padding='lg' radius="lg" color="dark">

    {#if ramInfo && lastMetrics}
    <Group position="apart">
        <div>
            <Text weight="semibold" size="sm">RAM</Text>
            <Space h={5} />
            <Text weight="medium" color="gray" size={10}>{lastMetrics.usage} / {ramInfo.total} GB</Text>
        </div>

        <Badge size="lg" radius="md" variant="filled" color="gray" style="align-self: center;">
            {lastMetrics.loadPercent.toFixed(1)}%
        </Badge>
    </Group>

    {:else}
    <Group position="apart">
        <Skeleton height={26} width={60} radius="md"   />
        <Skeleton height={26} width={15} radius="md"   />
    </Group>
    
    {/if}


    <RamChart ramMetric={metricInfo}/>

</Card>
