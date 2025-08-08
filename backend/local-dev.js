// Very basic local dev server (no Lambda). For quick testing.
import express from 'express';
import bodyParser from 'body-parser';
import fetch from 'node-fetch';

const app = express();
app.use(bodyParser.json());

app.get('/', (_req, res) => res.json({ ok: true }));

app.listen(4000, () => console.log('Local dev backend on :4000'));
