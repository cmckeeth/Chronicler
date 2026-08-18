import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { auth, isLoggedIn } from '../api';

export default function Login() {
  const [mode, setMode] = useState('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const nav = useNavigate();

  if (isLoggedIn()) { nav('/', { replace: true }); return null; }

  async function submit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    const token = mode === 'login'
      ? await auth.login(email, password)
      : await auth.register(email, password);
    setLoading(false);
    if (token) nav('/', { replace: true });
    else setError(mode === 'login' ? 'Invalid email or password.' : 'Registration failed. Try a different email.');
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        {/* Ransom Note cuts every letter from a different magazine; the CSS shows one
            mark and hides the other based on the active theme. */}
        <h1>
          <span className="plain-mark">Chronicler</span>
          <span className="ransom-mark" aria-label="Chronicler">
            {'Chronicler'.split('').map((ch, i) => (
              <span key={i} style={{
                fontFamily: ['Special Elite', 'Rye', 'Zilla Slab', 'Alfa Slab One', 'Cinzel', 'Monoton'][i % 6],
                background: ['#f4f1e8', '#141414', '#ff2d55', '#e8e4d9', '#00b3a4', '#d6d0bd'][(i * 5 + 2) % 6],
                color: [1, 2, 4].includes((i * 5 + 2) % 6) ? '#f4f1e8' : '#141414',
                transform: `rotate(${((i % 5) - 2) * 3.4}deg) translateY(${((i % 4) - 2) * 1.6}px)`,
                fontSize: `${1 + (i % 3) * 0.09}em`,
              }}>{ch}</span>
            ))}
          </span>
        </h1>
        <p className="auth-subtitle">Your audiobook library</p>

        <div className="auth-tabs">
          <button className={`tab${mode === 'login' ? ' active' : ''}`} onClick={() => setMode('login')}>Sign In</button>
          <button className={`tab${mode === 'register' ? ' active' : ''}`} onClick={() => setMode('register')}>Register</button>
        </div>

        <form className="auth-form" onSubmit={submit}>
          <input type="email" placeholder="Email" value={email} onChange={e => setEmail(e.target.value)} className="form-input" required />
          <input type="password" placeholder="Password" value={password} onChange={e => setPassword(e.target.value)} className="form-input" required />
          {error && <p className="auth-error">{error}</p>}
          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? '⚙ Working...' : mode === 'login' ? 'Sign In' : 'Create Account'}
          </button>
        </form>
      </div>
    </div>
  );
}
