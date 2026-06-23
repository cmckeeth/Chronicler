import { useState } from 'react';
import { chaptersApi } from '../api';

export default function ChapterEditor({ chapter, onClose, onSaved }) {
  const [title, setTitle] = useState(chapter.title || '');
  const [trackNumber, setTrackNumber] = useState(chapter.trackNumber ?? '');
  const [saving, setSaving] = useState(false);

  async function save(e) {
    e.preventDefault();
    setSaving(true);
    try {
      await chaptersApi.update(chapter.id, {
        title: title.trim(),
        trackNumber: trackNumber === '' ? null : parseInt(trackNumber),
      });
      await onSaved({ title: title.trim(), trackNumber: trackNumber === '' ? chapter.trackNumber : parseInt(trackNumber) });
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="meta-editor-overlay" onClick={onClose}>
      <div className="meta-editor" onClick={e => e.stopPropagation()}>
        <h3 style={{marginBottom:'.75rem',textAlign:'center'}}>Edit Chapter</h3>
        <form onSubmit={save} style={{display:'flex',flexDirection:'column',gap:'.4rem'}}>
          <label className="meta-label">Title</label>
          <input className="form-input" value={title} onChange={e => setTitle(e.target.value)} autoFocus />

          <label className="meta-label">Track #</label>
          <input className="form-input" type="number" value={trackNumber} onChange={e => setTrackNumber(e.target.value)} />

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
