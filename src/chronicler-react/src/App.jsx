import { useState, useEffect, useRef } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { isLoggedIn } from './api';
import Login from './pages/Login';
import Library from './pages/Library';
import Book from './pages/Book';
import Downloads from './pages/Downloads';

function Protected({ children }) {
  return isLoggedIn() ? children : <Navigate to="/login" replace />;
}

// Tesla-only: roving fractal lightning bolts on a canvas (matches the native apps).
// Animates only while the Tesla theme is active; the canvas is CSS-hidden otherwise.
function TeslaFX() {
  const ref = useRef(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let raf, W, H;
    const resize = () => { W = canvas.width = window.innerWidth; H = canvas.height = window.innerHeight; };
    resize();
    window.addEventListener('resize', resize);

    // Fractal midpoint-displacement bolt between two points.
    const makeBolt = () => {
      const x = Math.random() * W;
      let pts = [{ x, y: -20 }, { x: x + (Math.random() - 0.5) * W * 0.5, y: H + 20 }];
      let disp = W * 0.14;
      for (let d = 0; d < 6; d++) {
        const np = [];
        for (let i = 0; i < pts.length - 1; i++) {
          const a = pts[i], b = pts[i + 1];
          np.push(a, { x: (a.x + b.x) / 2 + (Math.random() - 0.5) * disp, y: (a.y + b.y) / 2 });
        }
        np.push(pts[pts.length - 1]);
        pts = np; disp *= 0.5;
      }
      return { pts, life: 1 };
    };

    let bolts = [];
    const stroke = (pts) => {
      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      for (const p of pts) ctx.lineTo(p.x, p.y);
      ctx.stroke();
    };
    const frame = () => {
      ctx.clearRect(0, 0, W, H);
      const active = document.documentElement.dataset.theme === 'tesla';
      if (active && Math.random() < 0.05) bolts.push(makeBolt());
      bolts = bolts.filter(b => (b.life -= 0.07) > 0);
      if (active) {
        ctx.lineCap = 'round';
        for (const b of bolts) {
          const a = Math.max(0, b.life);
          ctx.lineWidth = 5; ctx.strokeStyle = `rgba(43,196,255,${a * 0.35})`; stroke(b.pts);
          ctx.lineWidth = 1.4; ctx.strokeStyle = `rgba(210,244,255,${a})`; stroke(b.pts);
        }
      }
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => { cancelAnimationFrame(raf); window.removeEventListener('resize', resize); };
  }, []);
  return <canvas ref={ref} className="tesla-fx" aria-hidden="true" />;
}

// Steampunk-only decorative backdrop: exposed turning cogs + rising steam.
// Steampunk background: an old-timey industrial skyline of factories + smokestacks
// pinned to the bottom. The steam plumes (in SteampunkFX) are positioned to rise
// out of the chimney mouths. Shown only under [data-theme="steampunk"].
// Stack mouths sit at x ≈ 9% / 30% / 50% / 69% / 90% of width (see steam-* CSS).
function SteampunkBG() {
  return (
    <div className="steampunk-bg" aria-hidden="true">
      <svg className="factory-skyline" viewBox="0 0 1000 420" preserveAspectRatio="xMidYMax slice">
        <g className="sky-fill">
          {/* low industrial buildings (6) */}
          <rect x="0"   y="250" width="150" height="170" />
          <rect x="150" y="205" width="115" height="215" />
          <rect x="265" y="285" width="120" height="135" />
          <rect x="420" y="270" width="130" height="150" />
          <rect x="600" y="235" width="135" height="185" />
          <rect x="845" y="215" width="155" height="205" />
          {/* a big factory cogwheel */}
          <circle cx="372" cy="338" r="58" />
          {/* smokestacks: tall chimney + flared cap + two brick bands */}
          <g><rect x="78"  y="120" width="36" height="300" /><rect x="70"  y="112" width="52" height="20" /><rect x="78"  y="160" width="36" height="8" opacity="0.5" /></g>
          <g><rect x="286" y="68"  width="34" height="352" /><rect x="278" y="60"  width="50" height="20" /><rect x="286" y="110" width="34" height="8" opacity="0.5" /></g>
          <g><rect x="486" y="98"  width="36" height="322" /><rect x="478" y="90"  width="52" height="20" /><rect x="486" y="140" width="36" height="8" opacity="0.5" /></g>
          <g><rect x="676" y="56"  width="34" height="364" /><rect x="668" y="48"  width="50" height="20" /><rect x="676" y="98"  width="34" height="8" opacity="0.5" /></g>
          <g><rect x="886" y="128" width="36" height="292" /><rect x="878" y="120" width="52" height="20" /><rect x="886" y="168" width="36" height="8" opacity="0.5" /></g>
        </g>
      </svg>
    </div>
  );
}

// Always rendered; CSS reveals it only under [data-theme="steampunk"].
const GEAR = '⚙︎'; // ⚙ forced to text (not emoji) presentation so it takes brass color
function SteampunkFX() {
  return (
    <div className="steampunk-fx" aria-hidden="true">
      <span className="gear gear-a">{GEAR}</span>
      <span className="gear gear-b">{GEAR}</span>
      <span className="gear gear-c">{GEAR}</span>
      <span className="gear gear-d">{GEAR}</span>
      {/* Steam puffing out of the chimney mouths (anchored to the five stacks). */}
      <span className="steam steam-1" />
      <span className="steam steam-2" />
      <span className="steam steam-3" />
      <span className="steam steam-4" />
      <span className="steam steam-5" />
      <span className="steam steam-6" />
      <span className="steam steam-7" />
      <span className="steam steam-8" />
      <span className="steam steam-9" />
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
      <TeslaFX />
      <SteampunkBG />
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
