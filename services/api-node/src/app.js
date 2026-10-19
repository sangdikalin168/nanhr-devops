import express from 'express';

export const app = express();
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'api-node', version: process.env.APP_VERSION || 'dev' });
});

// Stand-in for the real attendance endpoints.
app.get('/attendance/today', (_req, res) => {
  res.json({ date: new Date().toISOString().slice(0, 10), checkedIn: 0, onLeave: 0 });
});
