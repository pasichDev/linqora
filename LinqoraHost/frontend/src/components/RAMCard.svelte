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

export let usage: String;
export let total: String;
export let usagePercentage: String;
export let ramLoad: number[] = [];
</script>
    <Box
    css={{
    padding: '$0 $8',
    }}>

    <Group position="apart">
        <div>
            <Text weight="semibold" size="sm">RAM</Text>
            <Space h={5} />
            <Text weight="medium" color="gray" size={10}>{usage} / {total} GB</Text>
        </div>

        <Badge size="lg" radius="md" variant="filled" color="gray" style="align-self: center;">
            {usagePercentage}%
        </Badge>
    </Group>




</Box>
