import { useEffect, useState } from 'react';

export default function Callback() {
  const [ok, setOk] = useState(false);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const code = params.get('code');
    if (!code) return;

    // In a real app, exchange code for tokens via a secure backend or Cognito Hosted UI.
    // For this starter, we assume you use Hosted UI for session cookies or add a token exchange endpoint.
    setOk(true);
  }, []);

  return <div style={{padding:24}}>
    <h2>Signed in</h2>
    <p>Complete token exchange in production.</p>
    <a href="/dashboard">Go to Dashboard</a>
  </div>
}
