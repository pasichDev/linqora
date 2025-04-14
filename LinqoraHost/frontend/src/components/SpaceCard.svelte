<script>
import {
    Space,
    Progress,
    Group,
    Box,
    Text,
    Badge
} from '@svelteuidev/core';
import {
    onMount
} from 'svelte';
import {
    GetSystemDisk
} from "../../wailsjs/go/main/App";

let systemDisk = {
    total_space: '',
    usage_space: '',
    model_disk: '',
    type_disk: ''
};

let usagePercentage = 0;
const getSystemDiskInfo = async () => {
    try {
        console.log('Fetching system info...');
        const info = await GetSystemDisk();
        console.log('Fetched info:', info);
        if (info && info.total_space && info.usage_space && info.model_disk && info.type_disk) {
            systemDisk = {
                ...info
            };
        usagePercentage = parseFloat(((info.usage_space / info.total_space) * 100).toFixed(2));

        } else {
            console.error('Invalid data format:', info);
        }
    } catch (err) {
        console.error('Error fetching system info:', err);
    }
};
//<Text weight="medium" color="gray" size={10}>{systemDisk.model_disk}</Text>
onMount(() => {
    
    getSystemDiskInfo();
   
});



</script>
<Box
    css={{
        padding: '$3 $5',
    }}>

    <Group position='apart'>
        <div>
            <Text weight={'bold'} size={12}> {systemDisk.model_disk}</Text>
           <Space h={5}/>
           <Text weight="medium" color="gray" size={10}>{systemDisk.usage_space} / {systemDisk.total_space} GB</Text>
          </div>
      

          <Badge size="lg" radius="md" variant="filled" color="gray" style="align-self: center;">
            {usagePercentage}%
          </Badge>
    </Group>
    <Space h="md" />
    <Progress value={usagePercentage}  size="md" radius="md" />
    
</Box>
