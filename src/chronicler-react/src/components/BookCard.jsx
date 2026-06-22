import { useNavigate } from 'react-router-dom';
import { booksApi } from '../api';

export default function BookCard({ book, onToggleFav }) {
  const nav = useNavigate();
  return (
    <div className="book-card" onClick={() => nav(`/book/${book.id}`)}>
      <div className="book-cover">
        {book.hasCover
          ? <img src={booksApi.coverUrl(book.id)} alt={book.title} loading="lazy" />
          : <div className="book-cover-placeholder">📚</div>
        }
        <button
          className={`fav-btn${book.isFavorite ? ' fav-active' : ''}`}
          title={book.isFavorite ? 'Remove from favorites' : 'Add to favorites'}
          onClick={e => { e.stopPropagation(); onToggleFav?.(book.id); }}
        >★</button>
      </div>
      <div className="book-meta">
        <span className="book-title">{book.title}</span>
        <span className="book-author">{book.author}</span>
        {book.narrator && <span className="book-narrator">Narrated by {book.narrator}</span>}
      </div>
    </div>
  );
}
