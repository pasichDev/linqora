<script lang="ts">
import {
    SvelteUIProvider,
    AppShell,
    Header,
    ShellSection
} from '@svelteuidev/core';
import TitleBar from './components/TitleBar.svelte';
import Home from './routes/Home.svelte';
import Settings from './routes/Settings.svelte';
import Router from 'svelte-spa-router';
import {
    _
} from 'svelte-i18n';
/**
 * Реалізувати першу ініціалізацію, а також сканування перифирії
 * При наступних запусках перевіряти чи доступна ця перифірія
 * Для чого? тому що ми будемо прицільно відстежувати сенсори девайсів 
 * а також надамо можливість користувачу вибирати які віджети необхідні на головному екрані
 * 
 * 
 */
const routes = {
    '/': Home,
    '/settings': Settings
};
</script>

<SvelteUIProvider withGlobalStyles themeObserver={'dark'}>

    <AppShell fixed
        navbarOffsetBreakpoint="sm"
        asideOffsetBreakpoint="sm" padding={5} style="height: 100vh; display: flex; flex-direction: column;">

        <Header slot="header"  height={32} fixed>    <TitleBar /></Header>
        <ShellSection   grow>

            <Router {routes} />

        </ShellSection>
    </AppShell>  </SvelteUIProvider>
