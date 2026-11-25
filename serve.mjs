import { createServer } from 'node:http'
import { readFile, stat } from 'node:fs/promises'
import { extname, join, resolve, sep } from 'node:path'

const root = resolve(process.env.STATIC_DIR || process.cwd())
const port = Number(process.env.PORT || 3000)

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.wasm': 'application/wasm',
  '.glb': 'model/gltf-binary',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.wav': 'audio/wav',
}

async function fileFor(pathname) {
  const clean = decodeURIComponent(pathname)
  const candidate = resolve(root, '.' + clean)
  if (candidate !== root && !candidate.startsWith(root + sep)) return null
  try {
    const info = await stat(candidate)
    if (info.isDirectory()) {
      const index = join(candidate, 'index.html')
      return (await stat(index)).isFile() ? index : null
    }
    return info.isFile() ? candidate : null
  } catch {
    return null
  }
}

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', 'http://localhost')
    if (url.pathname === '/__health') {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' })
      res.end(JSON.stringify({ ok: true, root }))
      return
    }
    let file = await fileFor(url.pathname)
    if (!file && !extname(url.pathname)) file = await fileFor('/index.html')
    if (!file) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' })
      res.end('Not found')
      return
    }
    const body = await readFile(file)
    res.writeHead(200, {
      'Content-Type': mime[extname(file).toLowerCase()] || 'application/octet-stream',
      'Content-Length': body.length,
      'Cache-Control': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
    })
    res.end(req.method === 'HEAD' ? undefined : body)
  } catch (error) {
    console.error('serve error:', error.message)
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' })
    res.end('Internal error')
  }
})

server.listen(port, '0.0.0.0', () => {
  console.log(`[serve] ${root} on http://0.0.0.0:${port}`)
})

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => server.close(() => process.exit(0)))
}
