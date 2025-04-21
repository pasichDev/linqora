import App from './App.svelte'
import './style.css'
import { register, init, getLocaleFromNavigator,addMessages } from 'svelte-i18n';
import en from './i18n/en.json';
import uk from './i18n/uk.json';


addMessages('en', en);
addMessages('uk', uk);
init({
  fallbackLocale: 'en',
  initialLocale: getLocaleFromNavigator(),
});


const app = new App({
  target: document.getElementById('app')
})

export default app
