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

// One growing vine: the stem "draws" itself in, leaves pop along it, then a
// flower blooms slowly at the tip.
function Vine({ cls, flower }) {
  return (
    <svg className={`vine-grow ${cls}`} viewBox="0 0 100 210" aria-hidden="true">
      <path className="vine-stem" d="M50,208 C22,172 84,140 42,102 C14,74 74,46 53,12" />
      <text className="vine-leaf vine-leaf-1" x="28" y="150" fontSize="21">🍃</text>
      <text className="vine-leaf vine-leaf-2" x="70" y="108" fontSize="19">🍃</text>
      <text className="vine-leaf vine-leaf-3" x="30" y="64"  fontSize="20">🍃</text>
      <text className="vine-flower" x="53" y="16" fontSize="46" textAnchor="middle">{flower}</text>
    </svg>
  );
}

// Garden-only backdrop: vines that grow + bloom at the tip, plus drifting petals.
function GardenFX() {
  return (
    <div className="garden-fx" aria-hidden="true">
      <Vine cls="vg-bl" flower="🌸" />
      <Vine cls="vg-br" flower="🌷" />
      <Vine cls="vg-bm" flower="🌼" />
      <span className="petal petal-1">🌸</span>
      <span className="petal petal-2">🌷</span>
      <span className="petal petal-3">🍃</span>
      <span className="petal petal-4">🌺</span>
      <span className="petal petal-5">🌸</span>
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
