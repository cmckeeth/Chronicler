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
  const [fav, setFav] = useState('all');        // 'all' | 'favorites'
  const [filter, setFilter] = useState('all');  // 'all' | 'books' | 'collections'
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
    } else {
      if (filter === 'all') q = q.filter(b => b.collectionId == null);   // standalone only (collections shown separately)
      else if (filter === 'collections') q = [];                          // collections-only view
      // filter === 'books' → every book, flat (incl. those inside collections)
      if (fav === 'favorites') q = q.filter(b => b.isFavorite);
    }
    return [...q].sort((a, b) => a.title.localeCompare(b.title));
  }, [books, filter, fav, searching]);

  // Collections show under "All"/"Collections" while browsing — but not in Favorites
  // (favorites are a book-level trait).
  const shownCollections = useMemo(() => {
    if (searching || fav === 'favorites' || (filter !== 'all' && filter !== 'collections')) return [];
    return [...collections].sort((a, b) => a.name.localeCompare(b.name));
  }, [collections, filter, fav, searching]);

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
            <button className={`chip${fav==='all'?' chip-active':''}`} onClick={() => setFav('all')}>All</button>
            <button className={`chip${fav==='favorites'?' chip-active':''}`} onClick={() => setFav('favorites')}>★ Favorites</button>
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
