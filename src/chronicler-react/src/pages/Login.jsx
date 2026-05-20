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
        <img src="/favicon.png" alt="Chronicler" style={{width:'80px',height:'80px',margin:'0 auto .5rem',display:'block',borderRadius:'18px'}} />
        <h1>Chronicler</h1>
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
