import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import type { AddressInfo } from 'node:net';
import type { IncomingMessage, ServerResponse } from 'node:http';

/**
 * Serve the packaged renderer from loopback and reverse-proxy `/api/*` to the
 * supervised `agent-toolkit serve`. Loading via file:// stamps Origin: null and
 * strips X-Atk-Desktop; loading from a different loopback port trips CORS
 * because serve emits no Access-Control-Allow-Origin. Same-origin static+proxy
 * keeps the security model (no browser CORS) while Desktop works.
 */

const TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.json': 'application/json',
  '.map': 'application/json',
};

function safeJoin(root: string, requestPath: string): string | null {
  const decoded = decodeURIComponent((requestPath.split('?')[0] ?? '/').split('#')[0] ?? '/');
  const relative = decoded === '/' ? 'index.html' : decoded.replace(/^\/+/, '');
  const resolved = path.resolve(root, relative);
  if (resolved !== root && !resolved.startsWith(root + path.sep)) return null;
  return resolved;
}

function proxyApi(
  req: IncomingMessage,
  res: ServerResponse,
  backendBase: string,
): void {
  const target = new URL(req.url ?? '/', backendBase);
  const headers: http.OutgoingHttpHeaders = { ...req.headers, host: target.host };
  // Drop hop-by-hop / browser-only headers that confuse the loopback serve.
  delete headers['origin'];
  delete headers['referer'];
  delete headers['sec-fetch-site'];
  delete headers['sec-fetch-mode'];
  delete headers['sec-fetch-dest'];
  // Mark Desktop first-party for mutating routes (serve security gate).
  headers['x-atk-desktop'] = '1';

  const upstream = http.request(
    {
      protocol: target.protocol,
      hostname: target.hostname,
      port: target.port,
      path: `${target.pathname}${target.search}`,
      method: req.method,
      headers,
    },
    (upstreamRes) => {
      res.writeHead(upstreamRes.statusCode ?? 502, upstreamRes.headers);
      upstreamRes.pipe(res);
    },
  );
  upstream.on('error', (error) => {
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: `backend proxy failed: ${error.message}` }));
  });
  res.once('close', () => {
    // EventSource keeps proxied requests open. If Desktop closes, abort the
    // upstream request too instead of leaving a backend socket orphaned.
    if (!upstream.destroyed) upstream.destroy();
  });
  req.pipe(upstream);
}

export interface RendererServer {
  /** Same-origin base the renderer should use for both UI and `/api` (no trailing slash). */
  url: string;
  setBackendTarget: (backendBaseUrl: string | null) => void;
  close: () => Promise<void>;
}

export async function startRendererServer(distDir: string): Promise<RendererServer> {
  const root = path.resolve(distDir);
  if (!fs.existsSync(path.join(root, 'index.html'))) {
    throw new Error(`Renderer dist missing index.html at ${root}`);
  }

  let backendBase: string | null = null;

  const server = http.createServer((req, res) => {
    const url = req.url ?? '/';
    if (url === '/api' || url.startsWith('/api/')) {
      if (!backendBase) {
        res.writeHead(503, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: 'backend not ready' }));
        return;
      }
      proxyApi(req, res, backendBase);
      return;
    }

    const filePath = safeJoin(root, url);
    if (!filePath) {
      res.writeHead(403).end('forbidden');
      return;
    }
    fs.readFile(filePath, (error, data) => {
      if (error) {
        if (error.code === 'ENOENT') {
          fs.readFile(path.join(root, 'index.html'), (fallbackError, html) => {
            if (fallbackError) {
              res.writeHead(404).end('not found');
              return;
            }
            res.writeHead(200, { 'content-type': TYPES['.html'] }).end(html);
          });
          return;
        }
        res.writeHead(500).end('error');
        return;
      }
      const type = TYPES[path.extname(filePath).toLowerCase()] ?? 'application/octet-stream';
      res.writeHead(200, { 'content-type': type, 'cache-control': 'no-cache' }).end(data);
    });
  });

  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => resolve());
  });

  const address = server.address() as AddressInfo;
  const url = `http://127.0.0.1:${address.port}`;
  return {
    url,
    setBackendTarget: (next) => {
      backendBase = next ? next.replace(/\/$/, '') : null;
    },
    close: () =>
      new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
        // Stop accepting first, then force active EventSource/API connections
        // closed so the callback cannot wait forever during app shutdown.
        server.closeAllConnections();
      }),
  };
}
