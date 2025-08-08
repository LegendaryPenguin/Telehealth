import { useEffect } from 'react';

export default function Login() {
  useEffect(() => {
    const domain = process.env.NEXT_PUBLIC_COGNITO_DOMAIN;
    const clientId = process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID;
    const redirect = encodeURIComponent(process.env.NEXT_PUBLIC_COGNITO_REDIRECT_URI);
    const url = `https://${domain}/oauth2/authorize?client_id=${clientId}&response_type=code&scope=email+openid+phone&redirect_uri=${redirect}`;
    window.location.href = url;
  }, []);

  return <p>Redirecting to Cognito…</p>;
}
