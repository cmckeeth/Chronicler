import { useState, useEffect, useRef } from 'react';
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
  const [reordering, setReordering] = useState(false);
  const [dragIndex, setDragIndex] = useState(null);
  const orderDirty = useRef(false);

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

  function onDragEnter(i) {
    if (dragIndex === null || i === dragIndex) return;
    setBooks(prev => {
      const next = [...prev];
      const [moved] = next.splice(dragIndex, 1);
      next.splice(i, 0, moved);
      return next;
    });
    setDragIndex(i);
    orderDirty.current = true;
  }

  async function onDragEnd() {
    setDragIndex(null);
    if (!orderDirty.current) return;
    orderDirty.current = false;
    try { await collectionsApi.reorder(id, books.map(b => b.id)); }
    catch (e) { setError(`Could not save order: ${e.message}`); }
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
        {!loading && !error && books.length > 1 && (
          <button
            className={`btn-reorder${reordering ? ' active' : ''}`}
            onClick={() => setReordering(r => !r)}
          >
            {reordering ? 'Done' : 'Reorder'}
          </button>
        )}
      </div>

      {loading ? (
        <div className="loading">Consulting the archive...</div>
      ) : error ? (
        <div className="empty-state"><p>The pneumatic tubes have failed: {error}</p></div>
      ) : books.length === 0 ? (
        <div className="empty-state"><p>This collection holds no volumes, traveller.</p></div>
      ) : (
        <div className={`book-grid${reordering ? ' reordering' : ''}`}>
          {books.map((book, i) => reordering ? (
            <div
              key={book.id}
              className={`book-drag${dragIndex === i ? ' dragging' : ''}`}
              draggable
              onDragStart={() => setDragIndex(i)}
              onDragEnter={() => onDragEnter(i)}
              onDragOver={e => e.preventDefault()}
              onDragEnd={onDragEnd}
              onClickCapture={e => { e.preventDefault(); e.stopPropagation(); }}
            >
              <BookCard book={book} onToggleFav={toggleFav} />
            </div>
          ) : (
            <BookCard key={book.id} book={book} onToggleFav={toggleFav} />
          ))}
        </div>
      )}
    </div>
  );
}
