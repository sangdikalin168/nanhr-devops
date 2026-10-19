import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { app } from '../src/app.js';

test('GET /health returns ok', async () => {
  const server = app.listen(0);
  await once(server, 'listening');
  const { port } = server.address();
  const res = await fetch(`http://127.0.0.1:${port}/health`);
  const body = await res.json();
  server.close();
  assert.equal(res.status, 200);
  assert.equal(body.status, 'ok');
});
