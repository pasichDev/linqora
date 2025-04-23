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
    cpu,
    systeminfo
} from 'wailsjs/go/models';

import {
    _
} from 'svelte-i18n';

export let cpuInfo: systeminfo.CpuInfo;
export let cpuMetrics: cpu.CpuMetrics[];
import CpuChart from '../charts/CpuChart.svelte';

let lastMetrics: cpu.CpuMetric | null;

$: {
    if (cpuMetrics.length > 0) {
        lastMetrics = cpuMetrics.reverse()[cpuMetrics.length - 1]; // Останній елемент масиву
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
     
        <Badge size="lg" radius="md" variant="filled" color="lime" style="align-self: center;">
            {lastMetrics.loadPercent.toFixed(2)}%
        </Badge>
        <Badge size="lg" radius="md" variant="filled" color="cyan" style="align-self: center;" >
            {lastMetrics.temperature.toFixed(0)}℃
        </Badge>

        {:else}
 
        <Skeleton height={26} width={15} radius="md"   />
        <Skeleton height={26} width={15} radius="md"   />
        {/if}

    </Group>

    <Space h="xs" />
    <CpuChart cpuMetric={cpuMetrics.reverse()} />
    <Divider color="dark" />
    <Space h="md" />

    {#if lastMetrics}
    {#if lastMetrics.processes !=0}
    <Group position='apart'>
        <Text weight={'medium'} size='xs'>{$_("processes")}</Text>
        <Text weight={'medium'} size='xs'>{lastMetrics.processes}</Text>
    </Group> {/if}
    <Space h="xs" />
    {#if lastMetrics.threads !=0}  <Group position='apart'>
        <Text weight={'medium'} size='xs'>{$_("threads")}</Text>
        <Text weight={'medium'} size='xs'>{lastMetrics.threads}</Text>
    </Group> {/if} {/if}
</Card>
