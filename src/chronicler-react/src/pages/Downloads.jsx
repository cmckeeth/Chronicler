import { useNavigate } from 'react-router-dom';

export default function Downloads() {
  const nav = useNavigate();
  return (
    <div className="library-browser">
      <div className="library-header">
        <div style={{display:'flex',alignItems:'center',gap:'.75rem'}}>
          <button className="btn-icon" onClick={() => nav('/')} style={{fontSize:'1.3rem',padding:'.3rem .5rem'}}>⌂</button>
          <h1>Downloads</h1>
        </div>
      </div>

      <div className="empty-state" style={{paddingTop:'4rem'}}>
        <p style={{fontSize:'1.1rem',marginBottom:'.75rem'}}>Not available in the browser.</p>
        <p style={{fontSize:'.85rem',opacity:.7}}>
          Downloads are stored locally on your device and are only available in the Android app.
          Open the app to manage offline listening.
        </p>
      </div>
    </div>
  );
}
