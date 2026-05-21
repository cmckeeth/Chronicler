import { useState } from 'react';
import { booksApi } from '../api';

export default function MetaEditor({ book, onClose, onSaved }) {
  const [title, setTitle] = useState(book.title || '');
  const [author, setAuthor] = useState(book.author || '');
  const [narrator, setNarrator] = useState(book.narrator || '');
  const [year, setYear] = useState(book.year || '');
  const [coverFile, setCoverFile] = useState(null);
  const [saving, setSaving] = useState(false);

  async function save(e) {
    e.preventDefault();
    setSaving(true);
    try {
      await booksApi.saveMeta(book.id, { title, author, narrator: narrator || null, year: year ? parseInt(year) : null });

      if (coverFile) {
        const formData = new FormData();
        formData.append('cover', coverFile, coverFile.name);
        const { getToken } = await import('../api');
        await fetch(`/api/books/${book.id}/cover/upload`, {
          method: 'PUT',
          headers: { 'Authorization': `Bearer ${localStorage.getItem('chronicler_token')}` },
          body: formData,
        });
      }

      await onSaved();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="meta-editor-overlay" onClick={onClose}>
      <div className="meta-editor" onClick={e => e.stopPropagation()}>
        <h3 style={{marginBottom:'.75rem',textAlign:'center'}}>Edit Details</h3>

        <form onSubmit={save} style={{display:'flex',flexDirection:'column',gap:'.4rem'}}>
          <label className="meta-label">Title</label>
          <input className="form-input" value={title} onChange={e => setTitle(e.target.value)} />

          <label className="meta-label">Author</label>
          <input className="form-input" value={author} onChange={e => setAuthor(e.target.value)} />

          <label className="meta-label">Narrator</label>
          <input className="form-input" value={narrator} onChange={e => setNarrator(e.target.value)} placeholder="(optional)" />

          <label className="meta-label">Year</label>
          <input className="form-input" type="number" value={year} onChange={e => setYear(e.target.value)} placeholder="(optional)" />

          <label className="meta-label" style={{marginTop:'.4rem'}}>
            Cover Image {book.hasCover ? '(replaces existing)' : ''}
          </label>
          <input
            type="file"
            accept="image/*"
            onChange={e => setCoverFile(e.target.files[0] || null)}
            style={{color:'var(--parchment-dim)',fontSize:'.8rem'}}
          />
          {coverFile && (
            <div style={{fontSize:'.7rem',color:'var(--verdigris)',marginTop:'.1rem'}}>
              📎 {coverFile.name}
            </div>
          )}

          <div style={{display:'flex',gap:'.5rem',marginTop:'.75rem',justifyContent:'center'}}>
            <button type="submit" className="btn-primary" disabled={saving}>
              {saving ? '⚙ Saving...' : 'Save'}
            </button>
            <button type="button" className="btn-secondary" onClick={onClose}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}
