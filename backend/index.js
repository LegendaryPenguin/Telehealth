import serverless from 'serverless-http';
import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import AWS from 'aws-sdk';
import { CognitoJwtVerifier } from 'aws-jwt-verify';
import { v4 as uuidv4 } from 'uuid';

const app = express();
app.use(cors());
app.use(bodyParser.json());

const dynamo = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3();
const polly = new AWS.Polly();
const lex = new AWS.LexRuntimeV2();

const TABLE_NAME = process.env.TABLE_NAME;
const UPLOADS_BUCKET = process.env.UPLOADS_BUCKET;
const COGNITO_USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;
const LEX_LOCALE_ID = process.env.LEX_LOCALE_ID || 'en_US';

const verifier = CognitoJwtVerifier.create({
  userPoolId: COGNITO_USER_POOL_ID,
  tokenUse: "id",
  clientId: process.env.COGNITO_CLIENT_ID || "unknown"
});

async function auth(req, res, next) {
  try {
    const token = (req.headers.authorization || '').replace('Bearer ', '');
    const payload = await verifier.verify(token);
    req.user = payload;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
}

app.get('/health', (req, res) => res.json({ ok: true }));

// Create or update a record
app.post('/records', auth, async (req, res) => {
  const { dataType, data } = req.body;
  const pk = `USER#${req.user.sub}`;
  const sk = `REC#${uuidv4()}`;
  await dynamo.put({
    TableName: TABLE_NAME,
    Item: { pk, sk, dataType, data, createdAt: Date.now() }
  }).promise();
  res.json({ ok: true, id: sk });
});

// List records
app.get('/records', auth, async (req, res) => {
  const pk = `USER#${req.user.sub}`;
  const out = await dynamo.query({
    TableName: TABLE_NAME,
    KeyConditionExpression: "pk = :pk and begins_with(sk, :rec)",
    ExpressionAttributeValues: { ":pk": pk, ":rec": "REC#" }
  }).promise();
  res.json(out.Items || []);
});

// Presigned upload URL
app.post('/uploads/presign', auth, async (req, res) => {
  const { fileName, contentType } = req.body;
  const key = `${req.user.sub}/${Date.now()}-${fileName}`;
  const url = s3.getSignedUrl('putObject', {
    Bucket: UPLOADS_BUCKET,
    Key: key,
    ContentType: contentType,
    Expires: 60,
    ServerSideEncryption: 'aws:kms'
  });
  res.json({ url, key });
});

// Lex text interaction
app.post('/voice/recognize', auth, async (req, res) => {
  const { text, botId, botAliasId } = req.body;
  const params = {
    botId,
    botAliasId,
    localeId: LEX_LOCALE_ID,
    sessionId: req.user.sub,
    text
  };
  try {
    const resp = await lex.recognizeText(params).promise();
    res.json(resp);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Polly TTS (returns presigned audio url)
app.post('/voice/tts', auth, async (req, res) => {
  const { text } = req.body;
  try {
    const synth = await polly.synthesizeSpeech({
      Text: text,
      VoiceId: 'Joanna',
      OutputFormat: 'mp3'
    }).promise();
    const key = `${req.user.sub}/tts-${Date.now()}.mp3`;
    await s3.putObject({
      Bucket: UPLOADS_BUCKET, Key: key, Body: synth.AudioStream, ContentType: 'audio/mpeg', ServerSideEncryption: 'aws:kms'
    }).promise();
    const url = s3.getSignedUrl('getObject', { Bucket: UPLOADS_BUCKET, Key: key, Expires: 300 });
    res.json({ url });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export const handler = serverless(app);
