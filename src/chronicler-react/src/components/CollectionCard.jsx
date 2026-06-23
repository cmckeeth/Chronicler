import { useState } from 'react';
import { createPortal } from 'react-dom';
import { useNavigate } from 'react-router-dom';
import { collectionsApi } from '../api';
import CollectionCoverEditor from './CollectionCoverEditor';

export default function CollectionCard({ collection }) {
  const nav = useNavigate();
  const count = collection.bookCount ?? 0;
  const [showCover, setShowCover] = useState(false);
  const [bust, setBust] = useState('');
  const [hasCover, setHasCover] = useState(collection.hasCover);

  return (
    <div
      className="collection-card"
      onClick={() => nav(`/collection/${collection.id}`)}
      onContextMenu={e => { e.preventDefault(); setShowCover(true); }}
      title="Right-click to set a cover"
    >
      {/* stacked-cards effect: two backing plates behind the cover */}
      <div className="collection-stack">
        <span className="stack-plate stack-plate-2" aria-hidden="true" />
        <span className="stack-plate stack-plate-1" aria-hidden="true" />
        <div className="collection-cover">
          {hasCover
            ? <img src={`${collectionsApi.coverUrl(collection.id)}${bust}`} alt={collection.name} loading="lazy" />
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

      {showCover && createPortal(
        // Stop clicks inside the modal from bubbling (through the React tree) back to the
        // card's onClick/onContextMenu, which would navigate into the collection.
        <div onClick={e => e.stopPropagation()} onContextMenu={e => { e.preventDefault(); e.stopPropagation(); }}>
          <CollectionCoverEditor
            collection={{ ...collection, hasCover }}
            onClose={() => setShowCover(false)}
            onSaved={() => { setHasCover(true); setBust(`?t=${Date.now()}`); setShowCover(false); }}
            onCleared={() => { setHasCover(false); setBust(`?t=${Date.now()}`); setShowCover(false); }}
          />
        </div>,
        document.body
      )}
    </div>
  );
}
