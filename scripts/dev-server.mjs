#!/usr/bin/env node
import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { join, extname, resolve } from 'node:path';
import { parse } from 'node:url';

// Parse command line arguments
const args = process.argv.slice(2);
function getArg(flag, defaultValue) {
  const index = args.indexOf(flag);
  if (index !== -1 && args[index + 1]) {
    return args[index + 1];
  }
  return defaultValue;
}

const PORT = parseInt(process.env.PORT || getArg('--port', '4321'), 10);
const HOST = process.env.HOST || getArg('--host', '0.0.0.0');

// Prefer dist/ if it exists, otherwise src/
const BASE_DIR = existsSync(resolve('dist')) ? resolve('dist') : resolve('src');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.txt': 'text/plain; charset=utf-8',
};

const server = createServer((req, res) => {
  const parsedUrl = parse(req.url);
  let pathname = decodeURIComponent(parsedUrl.pathname);

  // Health check endpoint for containers
  if (pathname === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK\n');
    return;
  }

  if (pathname === '/') {
    pathname = '/index.html';
  }

  let filePath = join(BASE_DIR, pathname);

  // Safe boundary check
  if (!filePath.startsWith(BASE_DIR)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('Forbidden');
    return;
  }

  // SPA fallback check
  if (!existsSync(filePath) || statSync(filePath).isDirectory()) {
    const fallbackPath = join(BASE_DIR, 'index.html');
    if (existsSync(fallbackPath)) {
      filePath = fallbackPath;
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not Found');
      return;
    }
  }

  const ext = extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  res.writeHead(200, {
    'Content-Type': contentType,
    'Cache-Control': 'no-cache',
    'X-Content-Type-Options': 'nosniff',
  });

  const stream = createReadStream(filePath);
  stream.on('error', () => {
    if (!res.headersSent) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Server Error');
    }
  });
  stream.pipe(res);
});

server.listen(PORT, HOST, () => {
  console.log(`🌱 [Dev Server] AI Gardening Mentor running at http://${HOST === '0.0.0.0' ? 'localhost' : HOST}:${PORT}`);
  console.log(`📁 Serving directory: ${BASE_DIR}`);
  console.log(`🩺 Healthcheck: http://${HOST === '0.0.0.0' ? 'localhost' : HOST}:${PORT}/healthz`);
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});
process.on('SIGINT', () => {
  server.close(() => process.exit(0));
});
