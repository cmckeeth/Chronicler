import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './styles.css';

// Apply the theme before first paint to avoid a flash of the default.
// Precedence: ?theme= query (also persisted) > saved choice > tesla.
const _urlTheme = new URLSearchParams(window.location.search).get('theme');
const _validThemes = ['tesla', 'steampunk', 'garden', 'academia', 'noir', 'west', 'neon', 'forge', 'ransom'];
const _theme = _validThemes.includes(_urlTheme)
  ? _urlTheme
  : (localStorage.getItem('chronicler_theme') || 'tesla');
if (_urlTheme) localStorage.setItem('chronicler_theme', _theme);
document.documentElement.dataset.theme = _theme;

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
