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

    <AppShell padding={0}>

        <Header slot="header" zIndex={10} height={24} >    <TitleBar /></Header>
        <slot>

            <Router {routes} />

        </slot>
    </AppShell>  </SvelteUIProvider>
