import { useState, useEffect } from 'react';
import { booksApi } from '../api';

const extFor = (type) => ({ 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' }[type] || 'jpg');

export default function MetaEditor({ book, onClose, onSaved }) {
  const [title, setTitle] = useState(book.title || '');
  const [author, setAuthor] = useState(book.author || '');
  const [narrator, setNarrator] = useState(book.narrator || '');
  const [year, setYear] = useState(book.year || '');
  const [description, setDescription] = useState(book.description || '');
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

  async function clearCover() {
    if (!confirm('Remove the cover for this book? This deletes cover.* from its folder.')) return;
    setSaving(true);
    try {
      const result = await booksApi.clearCover(book.id);
      if (result?.fileError) alert(`Cover cleared from the database, but a cover file could not be deleted:\n\n${result.fileError}`);
      await onSaved();
    } finally { setSaving(false); }
  }

  async function save(e) {
    e.preventDefault();
    setSaving(true);
    try {
      await booksApi.saveMeta(book.id, { title, author, narrator: narrator || null, year: year ? parseInt(year) : null, description: description || null });

      if (coverFile) {
        const formData = new FormData();
        formData.append('cover', coverFile, coverFile.name);
        const res = await fetch(`/api/books/${book.id}/cover/upload`, {
          method: 'PUT',
          headers: { 'Authorization': `Bearer ${localStorage.getItem('chronicler_token')}` },
          body: formData,
        });
        if (!res.ok) {
          const body = await res.text().catch(() => '');
          alert(`Cover upload failed: HTTP ${res.status}${res.status === 413 ? ' (image too large — exceeds the upload size limit)' : ''}\n\n${body.slice(0, 300)}`);
          setSaving(false);
          return;
        }
        const result = await res.json().catch(() => null);
        if (result && result.fileWritten === false) {
          alert(`Cover saved to the database, but the cover file could NOT be written to the audiobook folder:\n\n${result.fileError || 'unknown error'}\n\nPath: ${result.coverPath || '(book folder not found)'}`);
        }
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

          <label className="meta-label">Description</label>
          <textarea className="form-input" value={description} onChange={e => setDescription(e.target.value)} placeholder="(optional)" rows={4} style={{resize:'vertical',fontFamily:'inherit'}} />

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
          {book.hasCover && (
            <button type="button" className="btn-secondary" style={{fontSize:'.7rem',marginTop:'.3rem',alignSelf:'flex-start'}} onClick={clearCover} disabled={saving}>
              🗑 Clear cover
            </button>
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
