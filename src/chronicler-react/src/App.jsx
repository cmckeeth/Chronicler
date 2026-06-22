import { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { isLoggedIn } from './api';
import Login from './pages/Login';
import Library from './pages/Library';
import Book from './pages/Book';
import Downloads from './pages/Downloads';

function Protected({ children }) {
  return isLoggedIn() ? children : <Navigate to="/login" replace />;
}

// Steampunk-only decorative backdrop: exposed turning cogs + rising steam.
// Always rendered; CSS reveals it only under [data-theme="steampunk"].
const GEAR = '⚙︎'; // ⚙ forced to text (not emoji) presentation so it takes brass color
function SteampunkFX() {
  return (
    <div className="steampunk-fx" aria-hidden="true">
      <span className="gear gear-a">{GEAR}</span>
      <span className="gear gear-b">{GEAR}</span>
      <span className="gear gear-c">{GEAR}</span>
      <span className="gear gear-d">{GEAR}</span>
      <span className="steam steam-1" />
      <span className="steam steam-2" />
      <span className="steam steam-3" />
      <span className="steam steam-4" />
    </div>
  );
}

// Garden-only decorative backdrop: corner vines + drifting petals.
function GardenFX() {
  return (
    <div className="garden-fx" aria-hidden="true">
      <span className="vine vine-tl">🌿</span>
      <span className="vine vine-tr">🌿</span>
      <span className="vine vine-bl">🌿</span>
      <span className="vine vine-br">🌿</span>
      <span className="petal petal-1">🌸</span>
      <span className="petal petal-2">🌷</span>
      <span className="petal petal-3">🍃</span>
      <span className="petal petal-4">🌺</span>
      <span className="petal petal-5">🌸</span>
      {/* Flowers that bloom open on screen load */}
      <span className="bloom bloom-1">🌸</span>
      <span className="bloom bloom-2">🌷</span>
      <span className="bloom bloom-3">🌼</span>
      <span className="bloom bloom-4">🌺</span>
      <span className="bloom bloom-5">🌻</span>
      <span className="bloom bloom-6">🌷</span>
      <span className="bloom bloom-7">🌸</span>
    </div>
  );
}

function CornerControls() {
  const [theme, setTheme] = useState(() => localStorage.getItem('chronicler_theme') || 'tesla');
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    localStorage.setItem('chronicler_theme', theme);
  }, [theme]);
  return (
    <div className="corner-controls">
      <div className="version-badge" title={`Built ${__BUILD_TIME__} UTC`}>
        v{__APP_VERSION__} · {__BUILD_TIME__}
      </div>
      <select
        className="theme-select"
        value={theme}
        onChange={e => setTheme(e.target.value)}
        aria-label="Theme"
        title="Switch theme"
      >
        <option value="tesla">⚡ Tesla</option>
        <option value="steampunk">⚙ Steampunk</option>
        <option value="garden">🌿 Garden</option>
      </select>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <SteampunkFX />
      <GardenFX />
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<Protected><Library /></Protected>} />
        <Route path="/book/:id" element={<Protected><Book /></Protected>} />
        <Route path="/downloads" element={<Protected><Downloads /></Protected>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      <CornerControls />
    </BrowserRouter>
  );
}
