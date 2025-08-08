import { useState } from 'react';

export default function Voice() {
  const [text, setText] = useState('Hello, I need help with a sore throat.');
  const [resp, setResp] = useState(null);

  async function send() {
    const r = await fetch(process.env.NEXT_PUBLIC_API_URL + '/voice/recognize', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + (localStorage.getItem('id_token') || '') },
      body: JSON.stringify({
        text,
        botId: process.env.NEXT_PUBLIC_LEX_BOT_ID,
        botAliasId: process.env.NEXT_PUBLIC_LEX_BOT_ALIAS_ID
      })
    });
    const j = await r.json();
    setResp(j);
  }

  return <div style={{padding:24}}>
    <h2>Voice Agent</h2>
    <textarea value={text} onChange={e=>setText(e.target.value)} rows={4} style={{width:'100%'}} />
    <button onClick={send}>Send to Lex</button>
    <pre>{resp ? JSON.stringify(resp, null, 2) : null}</pre>
  </div>
}
