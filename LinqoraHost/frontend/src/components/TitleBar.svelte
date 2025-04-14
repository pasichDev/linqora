<script lang="ts">
import {
    Group,
    ThemeIcon,
    Button,
    Text,
    Paper
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

const maximize = () => {
    runtime.WindowMinimise();
};

const close = () => {
    runtime.Quit();
};
</script>

<header style="--wails-draggable:drag ">
    <Paper shadow="md" padding={2} >
        <Group position="apart" >
            <Text size="sm" weight="bold">LinqoraHost</Text>

            <Group spacing="xs" class="no-drag">
                <Button variant="subtle" color="gray" size="xs">
                    <SettingsAdjust />
                </Button>
                <Button variant="subtle" on:click={minimize} size="xs">
                    <Minimize />
                </Button>
                <Button variant="subtle" color="red" on:click={close} size="xs">
                    <Close />
                </Button>
            </Group>
        </Group>
    </Paper>
</header>
