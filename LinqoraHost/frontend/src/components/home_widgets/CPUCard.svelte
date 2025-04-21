<script lang="ts">
import {
    Space,
    Badge,
    Group,
    ThemeIcon,
    Text,
    Image,
    Divider,
    Skeleton,
    Card
} from '@svelteuidev/core';
import IconCpu from '../../assets/images/cpu.svg'
import {
    backend,
    database
} from 'wailsjs/go/models';
import {
    _
} from 'svelte-i18n';

export let cpuInfo: backend.CpuInfo;
export let cpuMetrics: database.CpuMetrics[];
import CpuChart from '../CpuChart.svelte';

let lastMetrics: database.CpuMetric | null;

$: {
    if (cpuMetrics.length > 0) {
        lastMetrics = cpuMetrics[cpuMetrics.length - 1]; // Останній елемент масиву
    } else {
        lastMetrics = null; // Якщо масив порожній
    }
}

</script>
<Card shadow='sm' padding='lg' radius="lg" color="dark">

    <Group position="apart">
        <div>
            <Text weight="semibold" size="sm">CPU</Text>
            <Space h={5} />
            <Text weight="medium" color="gray" size={10}>{cpuInfo.model}</Text>
        </div>

        <ThemeIcon radius="md" size="xl"  color="gray">
            <Image height={32} fit='contain' src={IconCpu} />
        </ThemeIcon>
    </Group>
    <Space h={5} />
    <Group position="left">

        {#if lastMetrics}
        <Badge size="lg" radius="md" variant="filled" color="teal" style="align-self: center;" >
           4.2 GHz
        </Badge>
        <Badge size="lg" radius="md" variant="filled" color="lime" style="align-self: center;">
            {lastMetrics.loadPercent.toFixed(2)}%
        </Badge>
        <Badge size="lg" radius="md" variant="filled" color="cyan" style="align-self: center;" >
            {lastMetrics.temperature.toFixed(0)}℃
        </Badge>
       
        {:else}
        <Skeleton height={26} width={15} radius="md"   />
        <Skeleton height={26} width={15} radius="md"   />
        <Skeleton height={26} width={15} radius="md"   />
        {/if}

    </Group>

    <Space h="xs" />
    <CpuChart cpuMetric={cpuMetrics} />
    <Divider color="dark" />
    <Space h="md" />
    <Group position='apart'>
        <Text weight={'medium'} size='xs'>{$_("processes")}</Text>
        <Text weight={'medium'} size='xs'>519</Text>
    </Group>
    <Space h="xs" />
    <Group position='apart'>
        <Text weight={'medium'} size='xs'>{$_("threads")}</Text>
        <Text weight={'medium'} size='xs'>2000</Text>
    </Group>
</Card>
