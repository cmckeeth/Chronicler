import { useState, useEffect, useRef } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { isLoggedIn } from './api';
import Login from './pages/Login';
import Library from './pages/Library';
import Book from './pages/Book';
import Collection from './pages/Collection';
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

// Garden-only BACKGROUND layer (behind content, ~50% opacity): real painted roses
// (rose + leafy stem) rising from the bottom + a couple set back in the corners.
// Each grows in on load and sways gently. Image: /rose.png (cut from the reference).
function GardenFX() {
  const roses = ['gr-1', 'gr-2', 'gr-3', 'gr-4', 'gr-5', 'gr-6', 'gr-bl', 'gr-br'];
  return (
    <div className="garden-fx" aria-hidden="true">
      {roses.map(c => (
        <span key={c} className={`rose ${c}`}><img src="/rose.png" alt="" /></span>
      ))}
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
        <Route path="/collection/:id" element={<Protected><Collection /></Protected>} />
        <Route path="/downloads" element={<Protected><Downloads /></Protected>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      <CornerControls />
    </BrowserRouter>
  );
}
