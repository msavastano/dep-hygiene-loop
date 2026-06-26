'use strict';

const request = require('supertest');
const app = require('../src/index');

// This test IS half of the loop's stop condition. The dep-review evaluator
// skill re-runs `npm test` after every dependency bump and only returns PASS
// if this (and lint) hold. It must pass on a clean checkout.
describe('GET /', () => {
  test('responds 200 with ok status', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.service).toBe('dep-hygiene-loop');
  });

  test('returns deduped dependency list', async () => {
    const res = await request(app).get('/');
    expect(res.body.deps).toEqual(['express', 'lodash']);
  });
});
