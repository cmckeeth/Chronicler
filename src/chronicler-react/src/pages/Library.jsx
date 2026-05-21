import { useState, useEffect, useCallback, useMemo } from 'react';
import { booksApi, auth } from '../api';
import BookCard from '../components/BookCard';

export default function Library() {
  const [books, setBooks] = useState([]);
  const [search, setSearch] = useState('');
  const [sort, setSort] = useState('name');
  const [filter, setFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [scanning, setScanning] = useState(false);

  const loadBooks = useCallback(async (q) => {
    setLoading(true);
    setError('');
    try { setBooks(await booksApi.list(q)); }
    catch (e) { if (e.message !== 'Unauthorized') setError(e.message); }
    setLoading(false);
  }, []);

  useEffect(() => { loadBooks(); }, [loadBooks]);

  useEffect(() => {
    const t = setTimeout(() => loadBooks(search), 300);
    return () => clearTimeout(t);
  }, [search, loadBooks]);

  const filtered = useMemo(() => {
    let q = books;
    if (filter === 'inprogress') q = q.filter(b => b.listenedCount > 0 && b.listenedCount < b.chapterCount);
    else if (filter === 'completed') q = q.filter(b => b.chapterCount > 0 && b.listenedCount >= b.chapterCount);

    if (sort === 'date') return [...q].sort((a, b) => new Date(b.addedAt) - new Date(a.addedAt));
    if (sort === 'progress') return [...q].sort((a, b) => {
      const aip = a.listenedCount > 0 && a.listenedCount < a.chapterCount;
      const bip = b.listenedCount > 0 && b.listenedCount < b.chapterCount;
      return (bip ? 1 : 0) - (aip ? 1 : 0) || a.title.localeCompare(b.title);
    });
    return [...q].sort((a, b) => a.title.localeCompare(b.title));
  }, [books, sort, filter]);

  const chip = (current, val, label) => (
    <button className={`chip${current === val ? ' chip-active' : ''}`} onClick={() => current === sort ? setSort(val) : setFilter(val)}>
      {label}
    </button>
  );

  async function scan() { setScanning(true); await booksApi.scan(); await loadBooks(search); setScanning(false); }

  return (
    <div className="library-browser">

      {/* Top: search + sort + filter */}
      <div className="library-top">
        <div style={{display:'flex',alignItems:'center',gap:'.6rem',marginBottom:'.6rem'}}>
          <input type="search" placeholder="Query the archive..." className="search-input"
            value={search} onChange={e => setSearch(e.target.value)} />
          <button className="btn-secondary" style={{fontSize:'.8rem',whiteSpace:'nowrap'}} onClick={auth.logout}>Sign Out</button>
        </div>
        <div className="library-controls">
          <div className="sort-group">
            <span className="control-label">Sort</span>
            <button className={`chip${sort==='name'?' chip-active':''}`} onClick={() => setSort('name')}>Name</button>
            <button className={`chip${sort==='date'?' chip-active':''}`} onClick={() => setSort('date')}>Added</button>
            <button className={`chip${sort==='progress'?' chip-active':''}`} onClick={() => setSort('progress')}>Progress</button>
          </div>
          <div className="sort-group">
            <span className="control-label">Show</span>
            <button className={`chip${filter==='all'?' chip-active':''}`} onClick={() => setFilter('all')}>All</button>
            <button className={`chip${filter==='inprogress'?' chip-active':''}`} onClick={() => setFilter('inprogress')}>In Progress</button>
            <button className={`chip${filter==='completed'?' chip-active':''}`} onClick={() => setFilter('completed')}>Done</button>
          </div>
        </div>
      </div>

      {/* Book grid */}
      {loading ? (
        <div className="loading">Consulting the archive...</div>
      ) : error ? (
        <div className="empty-state"><p>The pneumatic tubes have failed: {error}</p></div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <p>{books.length === 0 ? 'The archive lies empty, traveller.' : 'No volumes match this filter.'}</p>
        </div>
      ) : (
        <div className="book-grid">
          {filtered.map(book => <BookCard key={book.id} book={book} />)}
        </div>
      )}

      {/* Bottom: admin buttons */}
      <div className="library-bottom">
        <button className="btn-secondary" onClick={scan} disabled={scanning}>
          {scanning ? 'Cataloguing...' : 'Catalogue'}
        </button>
      </div>
    </div>
  );
}
