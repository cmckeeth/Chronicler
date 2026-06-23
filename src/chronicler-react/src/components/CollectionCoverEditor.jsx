import { useState, useEffect } from 'react';
import { collectionsApi } from '../api';

const extFor = (type) => ({ 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' }[type] || 'jpg');

export default function CollectionCoverEditor({ collection, onClose, onSaved }) {
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
    if (!coverFile) { onClose(); return; }
    setSaving(true);
    try {
      const result = await collectionsApi.uploadCover(collection.id, coverFile);
      if (result && result.fileWritten === false) {
        alert(`Cover saved to the database, but the cover file could NOT be written to the collection folder:\n\n${result.fileError || 'unknown error'}\n\nPath: ${result.coverPath || '(folder not found)'}`);
      }
      await onSaved();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="meta-editor-overlay" onClick={onClose}>
      <div className="meta-editor" onClick={e => e.stopPropagation()}>
        <h3 style={{marginBottom:'.75rem',textAlign:'center'}}>Collection Cover</h3>
        <div style={{fontSize:'.75rem',color:'var(--parchment-dim)',textAlign:'center',marginBottom:'.6rem'}}>
          {collection.name}
        </div>

        <form onSubmit={save} style={{display:'flex',flexDirection:'column',gap:'.4rem'}}>
          <label className="meta-label">
            Cover Image {collection.hasCover ? '(replaces existing)' : ''}
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
            <button type="submit" className="btn-primary" disabled={saving || !coverFile}>
              {saving ? '⚙ Saving...' : 'Save'}
            </button>
            <button type="button" className="btn-secondary" onClick={onClose}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}
