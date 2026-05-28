import { createReadStream, existsSync } from 'node:fs';
import { extname, join, normalize, resolve } from 'node:path';
import { createServer } from 'node:http';

const host = process.env.HOST ?? '127.0.0.1';
const port = Number(process.env.PORT ?? 8080);
const root = resolve(import.meta.dirname);

const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
};

function resolveRequestPath(url) {
  const requestPath = decodeURIComponent(new URL(url, `http://${host}`).pathname);
  const filePath = normalize(join(root, requestPath === '/' ? 'index.html' : requestPath));

  if (!filePath.startsWith(root)) {
    return null;
  }

  return existsSync(filePath) ? filePath : join(root, 'index.html');
}

const server = createServer((request, response) => {
  const filePath = resolveRequestPath(request.url ?? '/');

  if (!filePath) {
    response.writeHead(403);
    response.end('Forbidden');
    return;
  }

  response.writeHead(200, {
    'Content-Type': contentTypes[extname(filePath)] ?? 'text/plain; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  createReadStream(filePath).pipe(response);
});

server.listen(port, host, () => {
  console.log(`UniConnect Admin running at http://${host}:${port}`);
});
