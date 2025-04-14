<script>
import {
    SvelteUIProvider,
    AppShell,
    Header
} from '@svelteuidev/core';
import Main from './Main.svelte';

import TitleBar from './components/TitleBar.svelte';
</script>

<SvelteUIProvider withGlobalStyles themeObserver={'dark'}>

    <AppShell padding={0}>
        <Header slot="header" zIndex={10} height={24} >    <TitleBar /></Header>
        <slot>   <Main/>	</slot>
            </AppShell></SvelteUIProvider>
