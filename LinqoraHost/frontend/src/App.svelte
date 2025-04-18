<script lang="ts">
import {
    SvelteUIProvider,
    AppShell,
    Header,
} from '@svelteuidev/core';
import TitleBar from './components/TitleBar.svelte';
import Home from './routes/Home.svelte';
import Settings from './routes/Settings.svelte';
import Router from 'svelte-spa-router';
import {
    _
} from 'svelte-i18n';

const routes = {
    '/': Home,
    '/settings': Settings
};
</script>

<SvelteUIProvider withGlobalStyles themeObserver={'dark'}>

    <AppShell padding={0}>

        <Header slot="header" zIndex={10} height={24} >    <TitleBar /></Header>
        <slot>

            <Router {routes} />

        </slot>
    </AppShell>  </SvelteUIProvider>
