<script lang="ts">
import {
    Space,
    Badge,
    Card,
    Group,
    Image,
    Text,
    Box
} from '@svelteuidev/core';
import {
    backend
} from 'wailsjs/go/models';

export let ramInfo: backend.RamInfo;

$: usagePercentage = (ramInfo.total && !isNaN(ramInfo.usage)) ?
    ((ramInfo.usage / ramInfo.total) * 100).toFixed(2) :
    "0.00";
</script>
    <Box
    css={{
    padding: '$3 $5',
    }}>

    <Group position="apart">
        <div>
            <Text weight="semibold" size="sm">RAM</Text>
            <Space h={5} />
            <Text weight="medium" color="gray" size={10}>{ramInfo.usage } / {ramInfo.total } GB</Text>
        </div>

        <Badge size="lg" radius="md" variant="filled" color="gray" style="align-self: center;">
            {usagePercentage}%
        </Badge>
    </Group>

</Box>
