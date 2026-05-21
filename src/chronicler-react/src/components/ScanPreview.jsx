import { useState } from 'react';
import { booksApi } from '../api';

export default function ScanPreview({ onClose, onScanned }) {
  const [state, setState] = useState('idle'); // idle | loading | preview | scanning | done
  const [preview, setPreview] = useState(null);
  const [error, setError] = useState('');

  async function loadPreview() {
    setState('loading');
    setError('');
    try {
      const p = await booksApi.scanPreview();
      setPreview(p);
      setState('preview');
    } catch (e) {
      setError('Failed to load preview.');
      setState('idle');
    }
  }

  async function confirm() {
    setState('scanning');
    try {
      await booksApi.scan();
      setState('done');
      onScanned();
    } catch (e) {
      setError('Scan failed.');
      setState('preview');
    }
  }

  return (
    <div className="meta-editor-overlay" onClick={onClose}>
      <div className="meta-editor" onClick={e => e.stopPropagation()} style={{maxWidth:'440px'}}>
        <h3 style={{textAlign:'center',marginBottom:'.75rem'}}>Scan Library</h3>

        {state === 'idle' && (
          <>
            <p style={{fontSize:'.85rem',color:'var(--parchment-dim)',fontStyle:'italic',marginBottom:'.75rem',textAlign:'center'}}>
              Preview changes before applying. New book directories will be added, missing ones removed.
            </p>
            <div style={{display:'flex',gap:'.5rem',justifyContent:'center'}}>
              <button className="btn-primary" onClick={loadPreview}>Preview Changes</button>
              <button className="btn-secondary" onClick={onClose}>Cancel</button>
            </div>
          </>
        )}

        {state === 'loading' && (
          <div className="loading" style={{padding:'1.5rem 0'}}>⚙ Scanning directories...</div>
        )}

        {state === 'preview' && preview && (
          <>
            {!preview.hasChanges ? (
              <p style={{textAlign:'center',color:'var(--verdigris)',fontSize:'.9rem',padding:'.5rem 0'}}>
                ✓ No changes detected — library is up to date.
              </p>
            ) : (
              <div style={{display:'flex',flexDirection:'column',gap:'.6rem',margin:'.25rem 0'}}>
                {preview.newBooks.length > 0 && (
                  <div>
                    <div style={{fontSize:'.7rem',color:'var(--verdigris)',fontFamily:'var(--font-serif)',textTransform:'uppercase',letterSpacing:'1px',marginBottom:'.3rem'}}>
                      ⊕ Adding {preview.newBooks.length} book(s)
                    </div>
                    {preview.newBooks.map((t, i) => (
                      <div key={i} style={{fontSize:'.8rem',color:'var(--parchment)',padding:'.15rem .5rem',background:'var(--surface2)',borderRadius:'2px',marginBottom:'.15rem'}}>
                        {t}
                      </div>
                    ))}
                  </div>
                )}
                {preview.removedBooks.length > 0 && (
                  <div>
                    <div style={{fontSize:'.7rem',color:'var(--rust)',fontFamily:'var(--font-serif)',textTransform:'uppercase',letterSpacing:'1px',marginBottom:'.3rem'}}>
                      ⊖ Removing {preview.removedBooks.length} book(s) (files missing)
                    </div>
                    {preview.removedBooks.map((t, i) => (
                      <div key={i} style={{fontSize:'.8rem',color:'var(--parchment-dim)',padding:'.15rem .5rem',background:'var(--surface2)',borderRadius:'2px',marginBottom:'.15rem',textDecoration:'line-through'}}>
                        {t}
                      </div>
                    ))}
                  </div>
                )}
                {preview.coverUpdates > 0 && (
                  <div style={{fontSize:'.8rem',color:'var(--parchment-dim)',fontStyle:'italic'}}>
                    ⊙ {preview.coverUpdates} cover image(s) will be synced from disk
                  </div>
                )}
              </div>
            )}

            {error && <p style={{color:'var(--rust)',fontSize:'.8rem'}}>{error}</p>}

            <div style={{display:'flex',gap:'.5rem',justifyContent:'center',marginTop:'.75rem'}}>
              {preview.hasChanges && (
                <button className="btn-primary" onClick={confirm}>Apply Changes</button>
              )}
              <button className="btn-secondary" onClick={onClose}>
                {preview.hasChanges ? 'Cancel' : 'Close'}
              </button>
            </div>
          </>
        )}

        {state === 'scanning' && (
          <div className="loading" style={{padding:'1.5rem 0'}}>⚙ Applying changes...</div>
        )}

        {state === 'done' && (
          <>
            <p style={{textAlign:'center',color:'var(--verdigris)',fontSize:'.9rem',padding:'.5rem 0'}}>
              ✓ Library updated successfully.
            </p>
            <div style={{display:'flex',justifyContent:'center'}}>
              <button className="btn-secondary" onClick={onClose}>Close</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
