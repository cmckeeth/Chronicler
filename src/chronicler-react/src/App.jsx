import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { isLoggedIn } from './api';
import Login from './pages/Login';
import Library from './pages/Library';
import Book from './pages/Book';
import Downloads from './pages/Downloads';

function Protected({ children }) {
  return isLoggedIn() ? children : <Navigate to="/login" replace />;
}

function VersionBadge() {
  return (
    <div className="version-badge" title={`Built ${__BUILD_TIME__} UTC`}>
      v{__APP_VERSION__} · {__BUILD_TIME__}
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<Protected><Library /></Protected>} />
        <Route path="/book/:id" element={<Protected><Book /></Protected>} />
        <Route path="/downloads" element={<Protected><Downloads /></Protected>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      <VersionBadge />
    </BrowserRouter>
  );
}
