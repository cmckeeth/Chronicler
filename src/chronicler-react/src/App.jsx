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

// Shared gradient defs for the vector flowers (referenced by id across instances).
const FLOWER_HUES = [
  { id: 'rose',  light: '#ffd6e6', dark: '#ff4f8e' },
  { id: 'gold',  light: '#fff0bf', dark: '#ffa61f' },
  { id: 'lilac', light: '#ecd6ff', dark: '#9b54ff' },
  { id: 'white', light: '#ffffff', dark: '#cfe0e6' },
  { id: 'coral', light: '#ffd9bf', dark: '#ff6a3c' },
];
function FlowerDefs() {
  return (
    <svg className="garden-defs" width="0" height="0" aria-hidden="true">
      <defs>
        {FLOWER_HUES.map(h => (
          <radialGradient key={h.id} id={`pg-${h.id}`} cx="50%" cy="84%" r="78%">
            <stop offset="0%" stopColor={h.light} />
            <stop offset="62%" stopColor={h.dark} />
            <stop offset="100%" stopColor={h.dark} stopOpacity="0.85" />
          </radialGradient>
        ))}
        <radialGradient id="pg-center" cx="50%" cy="42%" r="62%">
          <stop offset="0%" stopColor="#ffe784" />
          <stop offset="55%" stopColor="#f0a800" />
          <stop offset="100%" stopColor="#9c6400" />
        </radialGradient>
      </defs>
    </svg>
  );
}

// A realistic-ish bloom: two offset rings of gradient-shaded petals + a textured
// golden center. `petals` controls density.
function Flower({ hue = 'rose', petals = 13 }) {
  const ring = (count, ry, cy, op, rot) =>
    Array.from({ length: count }).map((_, k) => (
      <ellipse key={`${ry}-${k}`} cx="50" cy={cy} rx={ry * 0.38} ry={ry}
        fill={`url(#pg-${hue})`} opacity={op}
        transform={`rotate(${rot + (360 / count) * k} 50 50)`} />
    ));
  return (
    <svg viewBox="0 0 100 100" aria-hidden="true">
      <g className="flower-art">
        {ring(petals, 26, 26, 0.95, 0)}
        {ring(petals, 19, 33, 0.95, 360 / petals / 2)}
        <circle cx="50" cy="50" r="13" fill="url(#pg-center)" />
        {Array.from({ length: 10 }).map((_, k) => (
          <circle key={`d-${k}`} cx={50 + 7 * Math.cos(k * 2.4)} cy={50 + 7 * Math.sin(k * 2.4)}
            r="1.5" fill="#7a4e00" opacity="0.5" />
        ))}
      </g>
    </svg>
  );
}

// One growing vine: the stem "draws" itself in, leaves unfurl along it, then a
// vector flower blooms slowly at the tip.
function Vine({ cls, hue }) {
  return (
    <div className={`vine-grow ${cls}`}>
      <svg className="vine-svg" viewBox="0 0 100 210" preserveAspectRatio="none" aria-hidden="true">
        <path className="vine-stem" d="M50,208 C22,172 84,140 42,102 C14,74 74,46 52,14" />
        <ellipse className="vine-leaf vine-leaf-1" cx="30" cy="150" rx="12" ry="5" fill="#5a9e46" transform="rotate(-32 30 150)" />
        <ellipse className="vine-leaf vine-leaf-2" cx="70" cy="104" rx="11" ry="4.6" fill="#5a9e46" transform="rotate(34 70 104)" />
        <ellipse className="vine-leaf vine-leaf-3" cx="32" cy="64"  rx="11" ry="4.6" fill="#5a9e46" transform="rotate(-28 32 64)" />
      </svg>
      <span className="vine-bloom"><Flower hue={hue} /></span>
    </div>
  );
}

// Garden-only BACKGROUND layer (behind content, ~50% opacity): large soft blooms,
// growing vines that bloom at the tip, and a few drifting flowers.
function GardenFX() {
  return (
    <div className="garden-fx" aria-hidden="true">
      <FlowerDefs />
      <span className="bg-flower bf-1"><Flower hue="rose" /></span>
      <span className="bg-flower bf-2"><Flower hue="gold" petals={15} /></span>
      <span className="bg-flower bf-3"><Flower hue="lilac" /></span>
      <span className="bg-flower bf-4"><Flower hue="coral" /></span>
      <span className="bg-flower bf-5"><Flower hue="white" petals={14} /></span>
      <Vine cls="vg-bl" hue="rose" />
      <Vine cls="vg-br" hue="white" />
      <Vine cls="vg-bm" hue="gold" />
      <span className="fall-flower ff-1"><Flower hue="rose" /></span>
      <span className="fall-flower ff-2"><Flower hue="lilac" /></span>
      <span className="fall-flower ff-3"><Flower hue="white" /></span>
      <span className="fall-flower ff-4"><Flower hue="coral" /></span>
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
