import { useState, useEffect, useCallback, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { booksApi, collectionsApi, auth } from '../api';
import BookCard from '../components/BookCard';
import CollectionCard from '../components/CollectionCard';
import ScanPreview from '../components/ScanPreview';

// The Archive's search, tab and filter. Kept at module level so they survive opening a
// book and coming back (the page unmounts in between). Reset on a full page reload.
const kept = { search: '', tab: 'favorites' };

export default function Library() {
  const nav = useNavigate();
  const [books, setBooks] = useState([]);
  const [collections, setCollections] = useState([]);
  const [search, setSearch] = useState(kept.search);
  const [tab, setTab] = useState(kept.tab);         // 'favorites' | 'books' | 'collections'
  useEffect(() => { Object.assign(kept, { search, tab }); }, [search, tab]);
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
    } else if (tab === 'collections') {
      q = [];                                   // Collections tab shows collections, no books
    } else if (tab === 'favorites') {
      q = q.filter(b => b.isFavorite);          // starred books, wherever they live
    }
    // tab 'books' → every book, flat (incl. those inside collections)
    return [...q].sort((a, b) => a.title.localeCompare(b.title));
  }, [books, tab, searching]);

  // Collections: all on the Collections tab, starred ones on Favorites, never while searching.
  const shownCollections = useMemo(() => {
    if (searching || tab === 'books') return [];
    const cs = tab === 'favorites' ? collections.filter(c => c.isFavorite) : collections;
    return [...cs].sort((a, b) => a.name.localeCompare(b.name));
  }, [collections, tab, searching]);

  async function scan() { setScanning(true); await booksApi.scan(); await loadBooks(search); setScanning(false); }

  const toggleFav = useCallback(async (bookId) => {
    setBooks(prev => prev.map(b => b.id === bookId ? { ...b, isFavorite: !b.isFavorite } : b));
    try { await booksApi.favorite(bookId); }
    catch { setBooks(prev => prev.map(b => b.id === bookId ? { ...b, isFavorite: !b.isFavorite } : b)); }
  }, []);

  const toggleCollectionFav = useCallback(async (id) => {
    setCollections(prev => prev.map(c => c.id === id ? { ...c, isFavorite: !c.isFavorite } : c));
    try { await collectionsApi.favorite(id); }
    catch { setCollections(prev => prev.map(c => c.id === id ? { ...c, isFavorite: !c.isFavorite } : c)); }
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
            <button className={`chip${tab==='favorites'?' chip-active':''}`} onClick={() => setTab('favorites')}>★ Favorites</button>
            <button className={`chip${tab==='books'?' chip-active':''}`} onClick={() => setTab('books')}>Books</button>
            <button className={`chip${tab==='collections'?' chip-active':''}`} onClick={() => setTab('collections')}>Collections</button>
          </div>
        </div>
      </div>

      {/* Book grid */}
      {loading ? (
        <div className="loading">Consulting the archive...</div>
      ) : error ? (
        /* Archive out of reach — offer the downloads route, same as the native apps. */
        <div className="empty-state">
          <p>The pneumatic tubes have failed: {error}</p>
          <button className="btn-secondary" style={{marginTop:'1rem'}} onClick={() => nav('/downloads')}>
            📥 Server unreachable — Local Downloads
          </button>
        </div>
      ) : filtered.length === 0 && shownCollections.length === 0 ? (
        <div className="empty-state">
          <p>{books.length === 0 && collections.length === 0 ? 'The archive lies empty, traveller.'
            : !searching && tab === 'favorites' ? 'No favorites yet. Tap the ★ on a book or collection to star it.'
            : 'No volumes match this filter.'}</p>
        </div>
      ) : (
        <div className={`book-grid${tab==='favorites' && !searching ? ' fav-grid' : ''}`}>
          {shownCollections.map(c => <CollectionCard key={`c-${c.id}`} collection={c} onToggleFav={toggleCollectionFav} />)}
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
