import { useNavigate } from 'react-router-dom';
import { collectionsApi } from '../api';

export default function CollectionCard({ collection }) {
  const nav = useNavigate();
  const count = collection.bookCount ?? 0;
  return (
    <div className="collection-card" onClick={() => nav(`/collection/${collection.id}`)}>
      {/* stacked-cards effect: two backing plates behind the cover */}
      <div className="collection-stack">
        <span className="stack-plate stack-plate-2" aria-hidden="true" />
        <span className="stack-plate stack-plate-1" aria-hidden="true" />
        <div className="collection-cover">
          {collection.hasCover
            ? <img src={collectionsApi.coverUrl(collection.id)} alt={collection.name} loading="lazy" />
            : <div className="book-cover-placeholder">📚</div>
          }
          <span className="collection-ribbon">Collection</span>
          <span className="collection-count" title={`${count} books`}>{count} books</span>
        </div>
      </div>
      <div className="book-meta">
        <span className="book-title">{collection.name}</span>
        <span className="book-author">{count} {count === 1 ? 'volume' : 'volumes'}</span>
      </div>
    </div>
  );
}
