<script lang="ts">
import {
    Space,
    Progress,
    Group,
    Card,
    Text,
    Badge
} from '@svelteuidev/core';
import {
    backend
} from 'wailsjs/go/models';

export let systemDiskInfo: backend.SystemDiskInfo[] = [];

/*
$: usagePercentage = (systemDiskInfo.total && !isNaN(systemDiskInfo.usage)) ?
    ((systemDiskInfo.usage / systemDiskInfo.total) * 100).toFixed(2) :
    "0.00";
    */
    $: usagePercentage = "0.00"
</script>
<Card shadow='sm' padding='lg' radius="lg" color="dark">
   
    {#each systemDiskInfo as disk (disk)}
    <Group position='apart'>
        <div>
            <Text weight={'bold'} size={12}> {disk.model}</Text>
            <Space h={5}/>
                <Text weight="medium" color="gray" size={10}>{disk.usage} / {disk.total} GB</Text>
                </div>

                <Badge size="lg" radius="md" variant="filled" color="gray" style="align-self: center;">
                    {usagePercentage}%
                </Badge>
                </Group>
                <Space h="md" />
                <Progress value={parseFloat(usagePercentage)}  size="md" radius="md" />
       <Space h="md" />
                {/each}
                </Card>
