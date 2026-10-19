import { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';

function Status({ name, url }) {
  const [state, setState] = useState('checking…');
  useEffect(() => {
    fetch(url)
      .then((r) => r.json())
      .then((b) => setState(`${b.status} (${b.version})`))
      .catch(() => setState('down'));
  }, [url]);
  return <li>{name}: {state}</li>;
}

function App() {
  return (
    <main style={{ fontFamily: 'system-ui', padding: 24 }}>
      <h1>NAN HR Admin</h1>
      <ul>
        <Status name="Node API" url="/api/health" />
        <Status name="FastAPI" url="/py/health" />
      </ul>
    </main>
  );
}

createRoot(document.getElementById('root')).render(<App />);
