import { useState, useEffect, useCallback, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { booksApi, collectionsApi, auth } from '../api';
import BookCard from '../components/BookCard';
import CollectionCard from '../components/CollectionCard';
import ScanPreview from '../components/ScanPreview';

export default function Library() {
  const nav = useNavigate();
  const [books, setBooks] = useState([]);
  const [collections, setCollections] = useState([]);
  const [search, setSearch] = useState('');
  const [sort, setSort] = useState('name');
  const [filter, setFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [scanning, setScanning] = useState(false);
  const [showScan, setShowScan] = useState(false);

  const loadBooks = useCallback(async (q) => {
    setLoading(true);
    setError('');
    try {
      const term = (q || '').trim();
      if (term) {
        // Searching: flat list of ALL books so books inside collections are findable.
        setBooks(await booksApi.list(term));
        setCollections([]);
      } else {
        // Browsing: fetch ALL books + collections; the filter chips derive what
        // shows (root-only, all books, collection books, etc.) client-side.
        const [bs, cs] = await Promise.all([
          booksApi.list(null),
          collectionsApi.list(),
        ]);
        setBooks(bs);
        setCollections(cs);
      }
    }
    catch (e) { if (e.message !== 'Unauthorized') setError(e.message); }
    setLoading(false);
  }, []);

  // Refetch from the API whenever the search term changes (debounced lightly).
  useEffect(() => {
    const t = setTimeout(() => loadBooks(search), 200);
    return () => clearTimeout(t);
  }, [search, loadBooks]);


  const searching = search.trim().length > 0;

  const filtered = useMemo(() => {
    let q = books;
    if (searching) {
      // Search shows every matching book, flat (collection books included).
    } else if (filter === 'all') {
      q = q.filter(b => b.collectionId == null);           // standalone only (collections shown separately)
    } else if (filter === 'collections') {
      q = [];                                              // collections-only view
    }
    // filter === 'books' → every book, flat (incl. those inside collections)

    if (sort === 'date') return [...q].sort((a, b) => new Date(b.addedAt) - new Date(a.addedAt));
    if (sort === 'progress') return [...q].sort((a, b) => {
      const aip = a.listenedCount > 0 && a.listenedCount < a.chapterCount;
      const bip = b.listenedCount > 0 && b.listenedCount < b.chapterCount;
      return (bip ? 1 : 0) - (aip ? 1 : 0) || a.title.localeCompare(b.title);
    });
    return [...q].sort((a, b) => a.title.localeCompare(b.title));
  }, [books, sort, filter, searching]);

  // Collections show only when browsing under "All" or "Collections".
  const shownCollections = useMemo(() => {
    if (searching || (filter !== 'all' && filter !== 'collections')) return [];
    if (sort === 'date') return [...collections].sort((a, b) => new Date(b.addedAt) - new Date(a.addedAt));
    return [...collections].sort((a, b) => a.name.localeCompare(b.name));
  }, [collections, filter, sort, searching]);

  const chip = (current, val, label) => (
    <button className={`chip${current === val ? ' chip-active' : ''}`} onClick={() => current === sort ? setSort(val) : setFilter(val)}>
      {label}
    </button>
  );

  async function scan() { setScanning(true); await booksApi.scan(); await loadBooks(search); setScanning(false); }

  const toggleFav = useCallback(async (bookId) => {
    setBooks(prev => prev.map(b => b.id === bookId ? { ...b, isFavorite: !b.isFavorite } : b));
    try { await booksApi.favorite(bookId); }
    catch { setBooks(prev => prev.map(b => b.id === bookId ? { ...b, isFavorite: !b.isFavorite } : b)); }
  }, []);

  return (
    <div className="library-browser">

      {/* Top: search + sort + filter */}
      <div className="library-top">
        <div style={{display:'flex',alignItems:'center',gap:'.6rem',marginBottom:'.6rem'}}>
          <input type="search" placeholder="Query the archive..." className="search-input"
            value={search} onChange={e => setSearch(e.target.value)} />
          <button className="btn-secondary" style={{fontSize:'.8rem',whiteSpace:'nowrap'}} onClick={() => setShowScan(true)}>⊕ Scan</button>
          <button className="btn-secondary" style={{fontSize:'.8rem',whiteSpace:'nowrap'}} onClick={() => nav('/downloads')}>⬇ Downloads</button>
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
            <button className={`chip${filter==='books'?' chip-active':''}`} onClick={() => setFilter('books')}>Books</button>
            <button className={`chip${filter==='collections'?' chip-active':''}`} onClick={() => setFilter('collections')}>Collections</button>
          </div>
        </div>
      </div>

      {/* Book grid */}
      {loading ? (
        <div className="loading">Consulting the archive...</div>
      ) : error ? (
        <div className="empty-state"><p>The pneumatic tubes have failed: {error}</p></div>
      ) : filtered.length === 0 && shownCollections.length === 0 ? (
        <div className="empty-state">
          <p>{books.length === 0 && collections.length === 0 ? 'The archive lies empty, traveller.' : 'No volumes match this filter.'}</p>
        </div>
      ) : (
        <div className="book-grid">
          {shownCollections.map(c => <CollectionCard key={`c-${c.id}`} collection={c} />)}
          {filtered.map(book => <BookCard key={book.id} book={book} onToggleFav={toggleFav} />)}
        </div>
      )}

      {showScan && (
        <ScanPreview
          onClose={() => setShowScan(false)}
          onScanned={() => { loadBooks(); setShowScan(false); }}
        />
      )}
    </div>
  );
}
