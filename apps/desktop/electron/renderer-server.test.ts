// @vitest-environment node
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import type { AddressInfo } from 'node:net';
import { afterEach, describe, expect, it } from 'vitest';
import { startRendererServer } from './renderer-server';

function get(url: string): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    http
      .get(url, (response) => {
        const chunks: Buffer[] = [];
        response.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
        response.on('end', () =>
          resolve({ status: response.statusCode ?? 0, body: Buffer.concat(chunks).toString('utf8') }),
        );
      })
      .on('error', reject);
  });
}

function post(url: string, body: string): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const target = new URL(url);
    const req = http.request(
      {
        protocol: target.protocol,
        hostname: target.hostname,
        port: target.port,
        path: `${target.pathname}${target.search}`,
        method: 'POST',
        headers: { 'content-type': 'application/json', 'content-length': Buffer.byteLength(body) },
      },
      (response) => {
        const chunks: Buffer[] = [];
        response.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
        response.on('end', () =>
          resolve({ status: response.statusCode ?? 0, body: Buffer.concat(chunks).toString('utf8') }),
        );
      },
    );
    req.on('error', reject);
    req.end(body);
  });
}

describe('startRendererServer', () => {
  const dirs: string[] = [];
  const backends: http.Server[] = [];

  afterEach(async () => {
    for (const dir of dirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
    await Promise.all(
      backends.splice(0).map(
        (server) =>
          new Promise<void>((resolve, reject) => {
            server.close((error) => (error ? reject(error) : resolve()));
          }),
      ),
    );
  });

  it('serves index.html from loopback', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-renderer-'));
    dirs.push(dir);
    fs.writeFileSync(path.join(dir, 'index.html'), '<!doctype html><title>ok</title>');
    const server = await startRendererServer(dir);
    try {
      expect(server.url).toMatch(/^http:\/\/127\.0\.0\.1:\d+$/);
      const response = await get(`${server.url}/`);
      expect(response.status).toBe(200);
      expect(response.body).toContain('<title>ok</title>');
    } finally {
      await server.close();
    }
  });

  it('never escapes the dist root', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-renderer-'));
    dirs.push(dir);
    fs.writeFileSync(path.join(dir, 'index.html'), 'ok');
    const server = await startRendererServer(dir);
    try {
      const response = await get(new URL('/../etc/passwd', `${server.url}/`).href);
      expect([200, 403, 404]).toContain(response.status);
      if (response.status === 200) expect(response.body).toBe('ok');
    } finally {
      await server.close();
    }
  });

  it('proxies /api to the supervised backend once targeted', async () => {
    const backend = http.createServer((req, res) => {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ ok: true, path: req.url, desktop: req.headers['x-atk-desktop'] }));
    });
    backends.push(backend);
    await new Promise<void>((resolve) => backend.listen(0, '127.0.0.1', resolve));
    const backendPort = (backend.address() as AddressInfo).port;

    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-renderer-'));
    dirs.push(dir);
    fs.writeFileSync(path.join(dir, 'index.html'), 'ok');
    const server = await startRendererServer(dir);
    try {
      const cold = await get(`${server.url}/api/v1/health`);
      expect(cold.status).toBe(503);
      server.setBackendTarget(`http://127.0.0.1:${backendPort}`);
      const warm = await post(`${server.url}/api/v1/project/list`, '{}');
      expect(warm.status).toBe(200);
      expect(JSON.parse(warm.body)).toMatchObject({ ok: true, path: '/api/v1/project/list', desktop: '1' });
    } finally {
      await server.close();
    }
  });
});
