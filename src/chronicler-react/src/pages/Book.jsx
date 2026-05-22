import { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { booksApi, chaptersApi } from '../api';
import MetaEditor from '../components/MetaEditor';

function fmt(s) {
  const t = Math.floor(s);
  const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), ss = t % 60;
  return h > 0 ? `${h}:${String(m).padStart(2,'0')}:${String(ss).padStart(2,'0')}` : `${m}:${String(ss).padStart(2,'0')}`;
}

export default function Book() {
  const { id } = useParams();
  const nav = useNavigate();
  const audioRef = useRef(null);

  const [book, setBook] = useState(null);
  const [coverBust, setCoverBust] = useState('');
  const [showMetaEditor, setShowMetaEditor] = useState(false);
  const [coverSearching, setCoverSearching] = useState(false);
  const longPressTimer = useRef(null);
  const [chapters, setChapters] = useState([]);
  const [progresses, setProgresses] = useState([]);
  const [currentIdx, setCurrentIdx] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [position, setPosition] = useState(0);
  const [duration, setDuration] = useState(0);
  const [speed, setSpeed] = useState(1);
  const lastSave = useRef(Date.now() - 15000);
  const started = useRef(false);

  useEffect(() => {
    async function load() {
      const [b, chs] = await Promise.all([
        booksApi.get(id),
        booksApi.chapters(id),
      ]);
      setBook(b);
  
      const progs = await Promise.all(chs.map(c => chaptersApi.getProgress(c.id)));
      setChapters(chs);
      setProgresses(progs);

      // Resume first unfinished chapter
      const resumeIdx = progs.findIndex((p, i) => !p.isListened && p.positionSeconds > 0);
      const startIdx = resumeIdx >= 0 ? resumeIdx : progs.findIndex(p => !p.isListened);
      setCurrentIdx(Math.max(0, startIdx >= 0 ? startIdx : 0));
    }
    load();
  }, [id]);

  const chapter = chapters[currentIdx];

  // Load audio when chapter changes
  useEffect(() => {
    if (!chapter || !audioRef.current) return;
    const audio = audioRef.current;
    audio.src = chaptersApi.audioUrl(chapter.id);
    audio.load();
    const startPos = progresses[currentIdx]?.positionSeconds ?? 0;
    audio.onloadedmetadata = () => {
      setDuration(audio.duration);
      if (!started.current && startPos > 1) audio.currentTime = startPos;
    };
    started.current = false;
    setPlaying(false);
    setPosition(progresses[currentIdx]?.positionSeconds ?? 0);
  }, [chapter?.id]);

  const saveProgress = useCallback(async (pos) => {
    if (!chapter) return;
    await chaptersApi.saveProgress(chapter.id, pos, audioRef.current?.duration ?? 0);
    setProgresses(prev => prev.map((p, i) => i === currentIdx ? { ...p, positionSeconds: pos } : p));
  }, [chapter, currentIdx]);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    const onPlay = () => setPlaying(true);
    const onPause = () => setPlaying(false);
    const onTime = () => {
      setPosition(audio.currentTime);
      if (Date.now() - lastSave.current > 10000) {
        lastSave.current = Date.now();
        saveProgress(audio.currentTime);
      }
    };
    const onEnded = () => {
      setProgresses(prev => prev.map((p, i) => i === currentIdx ? { ...p, isListened: true } : p));
      if (currentIdx < chapters.length - 1) setCurrentIdx(i => i + 1);
    };
    const onMeta = () => setDuration(audio.duration);

    audio.addEventListener('play', onPlay);
    audio.addEventListener('pause', onPause);
    audio.addEventListener('timeupdate', onTime);
    audio.addEventListener('ended', onEnded);
    audio.addEventListener('loadedmetadata', onMeta);
    return () => {
      audio.removeEventListener('play', onPlay);
      audio.removeEventListener('pause', onPause);
      audio.removeEventListener('timeupdate', onTime);
      audio.removeEventListener('ended', onEnded);
      audio.removeEventListener('loadedmetadata', onMeta);
    };
  }, [currentIdx, chapters.length, saveProgress]);

  function togglePlay() {
    const audio = audioRef.current;
    if (!audio) return;
    if (playing) { audio.pause(); saveProgress(audio.currentTime); }
    else {
      if (!started.current) {
        const startPos = progresses[currentIdx]?.positionSeconds ?? 0;
        if (startPos > 1) audio.currentTime = startPos;
        started.current = true;
      }
      audio.play();
    }
  }

  function seek(e) { if (audioRef.current) audioRef.current.currentTime = Number(e.target.value); }
  function skip(sec) { if (audioRef.current) audioRef.current.currentTime = Math.max(0, Math.min(duration, audioRef.current.currentTime + sec)); }
  function changeSpeed(e) {
    const s = Number(e.target.value);
    setSpeed(s);
    if (audioRef.current) audioRef.current.playbackRate = s;
  }


  async function resetBook() {
    await booksApi.resetProgress(id);
    setProgresses(prev => prev.map(() => ({ positionSeconds: 0, isListened: false })));
  }


  if (!book) return <div className="loading">Consulting the archive...</div>;

  return (
    <div className="book-player-page">
      <button className="btn-back" onClick={() => nav('/')}>Library</button>

      <div className="book-header">
        <div className="cover-container">
          {book.hasCover
            ? <img
                className="book-cover-small"
                src={`${booksApi.coverUrl(book.id)}${coverBust}`}
                alt={book.title}
                onContextMenu={e => { e.preventDefault(); setShowMetaEditor(true); }}
                title="Right-click to edit details"
              />
            : <div
                className="book-cover-small-placeholder"
                onContextMenu={e => { e.preventDefault(); setShowMetaEditor(true); }}
                title="Right-click to edit details"
              >📚</div>
          }
        </div>
        <div className="book-info">
          <h1>{book.title}</h1>
          <h2>{book.author}</h2>
          {book.narrator && <p className="narrator">{book.narrator}</p>}
        </div>
      </div>

      {chapter && (
        <div className="audio-player">
          <div className="player-info">
            <span className="player-title">{chapter.title}</span>
            {duration > 0 && <span className="player-time">{fmt(position)} / {fmt(duration)}</span>}
          </div>
          <div className="player-controls">
            <button className="btn-icon" onClick={() => skip(-30)}>⏮ 30s</button>
            <button className="btn-play" onClick={togglePlay}>{playing ? '⏸' : '▶'}</button>
            <button className="btn-icon" onClick={() => skip(30)}>30s ⏭</button>
            <select className="speed-select" value={speed} onChange={changeSpeed}>
              <option value={0.75}>0.75×</option>
              <option value={1}>1×</option>
              <option value={1.25}>1.25×</option>
              <option value={1.5}>1.5×</option>
              <option value={2}>2×</option>
            </select>
            <button className="btn-icon" onClick={() => setShowBmInput(true)}>🔖</button>
          </div>
          {duration > 0 && (
            <div className="player-progress">
              <input type="range" className="progress-bar" min={0} max={Math.floor(duration)} value={Math.floor(position)} onChange={seek} />
            </div>
          )}
        </div>
      )}

      <audio ref={audioRef} preload="auto" />

      {/* Chapter list */}
      {chapters.length > 0 && (
        <div className="chapter-list">
          <div className="chapter-list-header"><h3>Chapters</h3></div>
          {chapters.map((ch, i) => (
            <div
              key={ch.id}
              className={`chapter-item${i === currentIdx ? ' chapter-active' : ''}${progresses[i]?.isListened ? ' chapter-listened' : ''}`}
              onClick={() => { setCurrentIdx(i); started.current = false; }}
            >
              <span className="chapter-number">{ch.trackNumber}</span>
              <span className="chapter-title">{ch.title}</span>
              <span className="chapter-status">
                {progresses[i]?.isListened && <span className="listened-badge" title="Listened">✓</span>}
                {!progresses[i]?.isListened && progresses[i]?.positionSeconds > 0 && <span className="in-progress-badge">…</span>}
                {i === currentIdx && <span className="playing-badge">▶</span>}
              </span>
              <button className="btn-reset-chapter" onClick={async e => {
                e.stopPropagation();
                await chaptersApi.reset(ch.id);
                setProgresses(prev => prev.map((p, j) => j === i ? { positionSeconds: 0, isListened: false } : p));
              }}>↺</button>
            </div>
          ))}
        </div>
      )}



      <div style={{display:'flex',justifyContent:'center',padding:'.75rem 0 .25rem',borderTop:'1px solid var(--border)',marginTop:'.5rem'}}>
        <button className="btn-secondary" style={{fontSize:'.7rem',opacity:.5}} onClick={resetBook}>⚙ Reset All Progress</button>
      </div>

      {showMetaEditor && (
        <MetaEditor
          book={book}
          onClose={() => setShowMetaEditor(false)}
          onSaved={async () => {
            const b = await booksApi.get(id);
            setBook(b);
            setCoverBust(`?t=${Date.now()}`);
            setShowMetaEditor(false);
          }}
        />
      )}
    </div>
  );
}
