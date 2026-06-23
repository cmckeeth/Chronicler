import { useState, useEffect } from 'react';
import { booksApi } from '../api';

const extFor = (type) => ({ 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' }[type] || 'jpg');

export default function MetaEditor({ book, onClose, onSaved }) {
  const [title, setTitle] = useState(book.title || '');
  const [author, setAuthor] = useState(book.author || '');
  const [narrator, setNarrator] = useState(book.narrator || '');
  const [year, setYear] = useState(book.year || '');
  const [coverFile, setCoverFile] = useState(null);
  const [saving, setSaving] = useState(false);

  // Paste an image straight from the clipboard (⌘/Ctrl+V anywhere while open).
  useEffect(() => {
    function onPaste(e) {
      for (const item of e.clipboardData?.items ?? []) {
        if (item.type.startsWith('image/')) {
          const blob = item.getAsFile();
          if (blob) { setCoverFile(new File([blob], `pasted.${extFor(blob.type)}`, { type: blob.type })); e.preventDefault(); }
          return;
        }
      }
    }
    window.addEventListener('paste', onPaste);
    return () => window.removeEventListener('paste', onPaste);
  }, []);

  async function pasteFromClipboard() {
    try {
      for (const item of await navigator.clipboard.read()) {
        const type = item.types.find(t => t.startsWith('image/'));
        if (type) {
          const blob = await item.getType(type);
          setCoverFile(new File([blob], `pasted.${extFor(type)}`, { type }));
          return;
        }
      }
      alert('No image found on the clipboard.');
    } catch { alert('Clipboard access was blocked — copy an image, then press ⌘/Ctrl+V here instead.'); }
  }

  async function save(e) {
    e.preventDefault();
    setSaving(true);
    try {
      await booksApi.saveMeta(book.id, { title, author, narrator: narrator || null, year: year ? parseInt(year) : null });

      if (coverFile) {
        const formData = new FormData();
        formData.append('cover', coverFile, coverFile.name);
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
          <div style={{display:'flex',alignItems:'center',gap:'.5rem',flexWrap:'wrap'}}>
            <input
              type="file"
              accept="image/*"
              onChange={e => setCoverFile(e.target.files[0] || null)}
              style={{color:'var(--parchment-dim)',fontSize:'.8rem',flex:1,minWidth:'9rem'}}
            />
            <button type="button" className="btn-secondary" style={{fontSize:'.7rem',whiteSpace:'nowrap'}} onClick={pasteFromClipboard}>📋 Paste</button>
          </div>
          <div style={{fontSize:'.65rem',color:'var(--parchment-dim)',opacity:.7,marginTop:'.1rem'}}>…or press ⌘/Ctrl+V to paste a copied image</div>
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
