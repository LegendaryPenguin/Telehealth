import { useEffect, useState } from 'react';

export default function Dashboard() {
  const [records, setRecords] = useState([]);

  useEffect(() => {
    // Placeholder: fetch records with an ID token you store after real auth
  }, []);

  return <div style={{padding:24}}>
    <h2>Dashboard</h2>
    <ul>
      {records.map(r => <li key={r.sk}>{r.dataType}</li>)}
    </ul>
    <a href="/voice">Voice Agent</a>
  </div>
}
