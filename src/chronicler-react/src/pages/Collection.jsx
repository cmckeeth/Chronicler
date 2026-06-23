import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { collectionsApi, booksApi } from '../api';
import BookCard from '../components/BookCard';

export default function Collection() {
  const { id } = useParams();
  const nav = useNavigate();
  const [collection, setCollection] = useState(null);
  const [books, setBooks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      setError('');
      try {
        const [c, bs] = await Promise.all([
          collectionsApi.get(id),
          collectionsApi.books(id),
        ]);
        if (cancelled) return;
        setCollection(c);
        setBooks(bs);
      } catch (e) {
        if (!cancelled && e.message !== 'Unauthorized') setError(e.message);
      }
      if (!cancelled) setLoading(false);
    }
    load();
    return () => { cancelled = true; };
  }, [id]);

  async function toggleFav(bookId) {
    setBooks(prev => prev.map(b => b.id === bookId ? { ...b, isFavorite: !b.isFavorite } : b));
    try { await booksApi.favorite(bookId); }
    catch { setBooks(prev => prev.map(b => b.id === bookId ? { ...b, isFavorite: !b.isFavorite } : b)); }
  }

  return (
    <div className="library-browser">
      <div className="library-top">
        <button className="btn-back" onClick={() => nav('/')}>Library</button>
        <h1 className="collection-page-title">{collection?.name || 'Collection'}</h1>
        {collection && (
          <span className="collection-page-sub">
            {collection.bookCount} {collection.bookCount === 1 ? 'volume' : 'volumes'}
          </span>
        )}
      </div>

      {loading ? (
        <div className="loading">Consulting the archive...</div>
      ) : error ? (
        <div className="empty-state"><p>The pneumatic tubes have failed: {error}</p></div>
      ) : books.length === 0 ? (
        <div className="empty-state"><p>This collection holds no volumes, traveller.</p></div>
      ) : (
        <div className="book-grid">
          {books.map(book => <BookCard key={book.id} book={book} onToggleFav={toggleFav} />)}
        </div>
      )}
    </div>
  );
}
