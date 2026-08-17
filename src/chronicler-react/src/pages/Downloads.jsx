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
        <p style={{fontSize:'1.1rem',marginBottom:'.75rem'}}>Nothing stored in this browser.</p>
        <p style={{fontSize:'.85rem',opacity:.7}}>
          The web app streams straight from the server, so there's nothing to play while it's
          unreachable. The iOS and Android apps keep downloaded chapters on the device and can
          play them offline — open one of those to listen without a connection.
        </p>
      </div>
    </div>
  );
}
