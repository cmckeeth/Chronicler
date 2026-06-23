import { useNavigate } from 'react-router-dom';
import { booksApi } from '../api';

function fmtDur(s) {
  const t = Math.floor(s || 0);
  const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

export default function BookCard({ book, onToggleFav }) {
  const nav = useNavigate();
  const rows = [
    ['Author', book.author],
    ['Narrator', book.narrator],
    ['Year', book.year],
    ['Duration', book.durationSeconds ? fmtDur(book.durationSeconds) : null],
    ['Chapters', book.chapterCount ? `${book.listenedCount || 0} / ${book.chapterCount} listened` : null],
    ['Added', book.addedAt ? new Date(book.addedAt).toLocaleDateString() : null],
  ].filter(([, v]) => v != null && v !== '');

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

      <div className="book-tooltip" role="tooltip">
        <div className="book-tooltip-title">{book.title}</div>
        {rows.map(([k, v]) => (
          <div className="book-tooltip-row" key={k}>
            <span className="book-tooltip-key">{k}</span>
            <span className="book-tooltip-val">{v}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
