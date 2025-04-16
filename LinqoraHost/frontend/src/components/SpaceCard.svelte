<script lang="ts">
import {
    Space,
    Progress,
    Group,
    Box,
    Text,
    Badge
} from '@svelteuidev/core';
import {
    backend
} from 'wailsjs/go/models';

export let systemDiskInfo: backend.SystemDiskInfo;

$: usagePercentage = (systemDiskInfo.total && !isNaN(systemDiskInfo.usage)) ?
    ((systemDiskInfo.usage / systemDiskInfo.total) * 100).toFixed(2) :
    "0.00";
</script>
<Box
    css={{
    padding: '$3 $5',
    }}>

    <Group position='apart'>
        <div>
            <Text weight={'bold'} size={12}> {systemDiskInfo.model}</Text>
            <Space h={5}/>
                <Text weight="medium" color="gray" size={10}>{systemDiskInfo.usage} / {systemDiskInfo.total} GB</Text>
                </div>

                <Badge size="lg" radius="md" variant="filled" color="gray" style="align-self: center;">
                    {usagePercentage}%
                </Badge>
                </Group>
                <Space h="md" />
                <Progress value={parseFloat(usagePercentage)}  size="md" radius="md" />

                </Box>
