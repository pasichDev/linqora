<script>
    import {
        Space,
        Badge,
        Card,
        Group,
        Image,
        Text,
        Box
    } from '@svelteuidev/core';

    
    export let usage;
    export let total;
    $: usagePercentage = (total && !isNaN(usage))
        ? ((usage / total) * 100).toFixed(2)
        : "0.00";
    </script>
    <Box
    css={{
        padding: '$3 $5',
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
    