<script lang="ts">
import {
    _
} from 'svelte-i18n';
import {
    Group,
    Button,
    Text,
    Paper,
    Tooltip,

    Space

} from '@svelteuidev/core';
import * as runtime from '../../wailsjs/runtime/runtime';
import {
    SettingsAdjust,
    Close,
    Minimize

} from "carbon-icons-svelte";
const minimize = () => {
    runtime.WindowMinimise();
};

const close = () => {
    runtime.Quit();
};
</script>

<header style="--wails-draggable:drag">
    <Paper shadow="md" padding={5} >
        <Group position="apart" >
            
            <div style="padding-left: 10px;">
            <Text size="sm" weight="bold">LinqoraHost</Text> </div>
            <Group spacing="xs" class="no-drag">
                <Tooltip label={$_("settings")} openDelay={500}>
                    <Button variant="subtle" color="gray" size="xs" href="#/settings">
                        <SettingsAdjust />
                    </Button>
                </Tooltip>
                
                <Tooltip label={$_("minimize")} openDelay={500}>
                    <Button variant="subtle" on:click={minimize} size="xs">
                        <Minimize />
                    </Button>
                </Tooltip>
                
                <Tooltip label={$_("closeApp")} openDelay={500}>
                    <Button variant="subtle" color="red" on:click={close} size="xs">
                        <Close />
                    </Button>
                </Tooltip>
                
                        </Group>
                        </Group>
                        </Paper>
                        </header>
