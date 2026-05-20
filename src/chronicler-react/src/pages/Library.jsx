import { useState, useEffect, useCallback } from 'react';
import { booksApi, auth } from '../api';
import BookCard from '../components/BookCard';

export default function Library() {
  const [books, setBooks] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [scanning, setScanning] = useState(false);
  const [enriching, setEnriching] = useState(false);

  const loadBooks = useCallback(async (q) => {
    setLoading(true);
    setError('');
    try {
      setBooks(await booksApi.list(q));
    } catch (e) {
      if (e.message !== 'Unauthorized') setError(e.message);
    }
    setLoading(false);
  }, []);

  useEffect(() => { loadBooks(); }, [loadBooks]);

  useEffect(() => {
    const t = setTimeout(() => loadBooks(search), 300);
    return () => clearTimeout(t);
  }, [search, loadBooks]);

  async function scan() {
    setScanning(true);
    await booksApi.scan();
    await loadBooks(search);
    setScanning(false);
  }

  async function enrich() {
    setEnriching(true);
    await booksApi.enrich();
    await loadBooks(search);
    setEnriching(false);
  }

  return (
    <div className="library-browser">
      <div className="library-header">
        <h1>The Archive</h1>
        <div className="library-toolbar">
          <input
            type="search"
            placeholder="Query the archive..."
            className="search-input"
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
          <button className="btn-secondary" onClick={scan} disabled={scanning}>
            {scanning ? '⚙ Cataloguing...' : '⚙ Catalogue'}
          </button>
          <button className="btn-secondary" onClick={enrich} disabled={enriching}>
            {enriching ? '⚙ Fetching...' : '⚙ Fetch Covers'}
          </button>
          <button className="btn-secondary" onClick={auth.logout} style={{marginLeft:'auto'}}>Sign Out</button>
        </div>
      </div>

      {loading ? (
        <div className="loading">Consulting the archive...</div>
      ) : error ? (
        <div className="empty-state"><p>The pneumatic tubes have failed: {error}</p></div>
      ) : books.length === 0 ? (
        <div className="empty-state">
          <p>The archive lies empty, traveller.</p>
          <p>Deposit volumes in the Library vault and engage the Catalogue mechanism.</p>
        </div>
      ) : (
        <div className="book-grid">
          {books.map(book => <BookCard key={book.id} book={book} />)}
        </div>
      )}
    </div>
  );
}
