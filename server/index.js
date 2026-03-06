const express = require('express');
const jwt = require('jsonwebtoken');
const { execSync, exec } = require('child_process');
const fs = require('fs');
const http = require('http');

const app = express();
app.use(express.json());

const PORT = 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'alist-rclone-secret-key-' + Date.now();
const WEB_USERNAME = process.env.WEB_USERNAME || 'admin';
const WEB_PASSWORD = process.env.WEB_PASSWORD || 'admin';
const RCLONE_ADDR = process.env.RCLONE_ADDR || 'http://127.0.0.1:5572';

// ========================
// Auth Middleware
// ========================
function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// ========================
// Rclone RC API Helper
// ========================
function rcloneRC(command, params = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(params);
    const url = new URL(command, RCLONE_ADDR);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) },
      timeout: 10000,
    };
    const req = http.request(options, (resp) => {
      let body = '';
      resp.on('data', (chunk) => (body += chunk));
      resp.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch { resolve(body); }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Rclone RC timeout')); });
    req.write(data);
    req.end();
  });
}

// ========================
// Auth Routes
// ========================
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  if (username === WEB_USERNAME && password === WEB_PASSWORD) {
    const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: '24h' });
    res.cookie('_auth_token', token, { httpOnly: true, sameSite: 'lax', path: '/', maxAge: 86400000 });
    return res.json({ token, username });
  }
  return res.status(401).json({ error: 'Invalid credentials' });
});

app.get('/api/auth/check', authMiddleware, (req, res) => {
  res.json({ valid: true, username: req.user.username });
});

// Cookie-based auth check for nginx auth_request
app.get('/api/auth/cookie', (req, res) => {
  const token = req.cookies?._auth_token || req.headers.cookie?.match(/_auth_token=([^;]+)/)?.[1];
  if (!token) return res.status(401).end();
  try {
    jwt.verify(token, JWT_SECRET);
    return res.status(200).end();
  } catch {
    return res.status(401).end();
  }
});

// ========================
// Status Routes
// ========================
app.get('/api/status', authMiddleware, async (req, res) => {
  const status = { alist: 'stopped', rclone: 'stopped' };

  // Check Alist
  try {
    const result = execSync('supervisorctl status alist 2>/dev/null', { encoding: 'utf-8', timeout: 5000 });
    status.alist = result.includes('RUNNING') ? 'running' : 'stopped';
  } catch { status.alist = 'stopped'; }

  // Check Rclone
  try {
    await rcloneRC('/rc/noop');
    status.rclone = 'running';
  } catch { status.rclone = 'stopped'; }

  // System info
  try {
    const uptime = fs.readFileSync('/proc/uptime', 'utf-8').split(' ')[0];
    status.uptime = Math.floor(parseFloat(uptime));
  } catch { status.uptime = 0; }

  res.json(status);
});

// ========================
// Rclone Remote Management
// ========================
app.get('/api/rclone/remotes', authMiddleware, async (req, res) => {
  try {
    const result = await rcloneRC('/config/listremotes');
    const remotes = result.remotes || [];
    const details = [];
    for (const name of remotes) {
      try {
        const dump = await rcloneRC('/config/get', { name });
        details.push({ name, ...dump });
      } catch {
        details.push({ name, type: 'unknown' });
      }
    }
    res.json({ remotes: details });
  } catch (err) {
    res.status(500).json({ error: 'Failed to list remotes: ' + err.message });
  }
});

app.post('/api/rclone/remote', authMiddleware, async (req, res) => {
  try {
    const { name, type, parameters } = req.body;
    if (!name || !type) return res.status(400).json({ error: 'name and type are required' });
    await rcloneRC('/config/create', { name, type, parameters: parameters || {} });
    res.json({ success: true, message: `Remote "${name}" created` });
  } catch (err) {
    res.status(500).json({ error: 'Failed to create remote: ' + err.message });
  }
});

app.put('/api/rclone/remote/:name', authMiddleware, async (req, res) => {
  try {
    const { name } = req.params;
    const { parameters } = req.body;
    await rcloneRC('/config/update', { name, parameters: parameters || {} });
    res.json({ success: true, message: `Remote "${name}" updated` });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update remote: ' + err.message });
  }
});

app.delete('/api/rclone/remote/:name', authMiddleware, async (req, res) => {
  try {
    const { name } = req.params;
    await rcloneRC('/config/delete', { name });
    res.json({ success: true, message: `Remote "${name}" deleted` });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete remote: ' + err.message });
  }
});

app.get('/api/rclone/providers', authMiddleware, async (req, res) => {
  try {
    const result = await rcloneRC('/config/providers');
    // Rclone RC returns providers with varying field names, normalize them
    const raw = result.providers || [];
    const providers = raw.map((p) => ({
      name: p.Name || p.name || '',
      description: p.Description || p.description || '',
      prefix: p.Prefix || p.prefix || p.Name || p.name || '',
    }));
    res.json({ providers });
  } catch (err) {
    res.status(500).json({ error: 'Failed to get providers: ' + err.message });
  }
});

// ========================
// Service Management
// ========================
app.post('/api/service/restart', authMiddleware, (req, res) => {
  const { service } = req.body;
  const allowed = ['alist', 'rclone', 'nginx'];
  if (!allowed.includes(service)) return res.status(400).json({ error: 'Invalid service' });
  try {
    execSync(`supervisorctl restart ${service}`, { encoding: 'utf-8', timeout: 15000 });
    res.json({ success: true, message: `${service} restarted` });
  } catch (err) {
    res.status(500).json({ error: 'Restart failed: ' + err.message });
  }
});

app.get('/api/logs/:service', authMiddleware, (req, res) => {
  const { service } = req.params;
  const allowed = ['alist', 'rclone', 'nginx', 'api'];
  if (!allowed.includes(service)) return res.status(400).json({ error: 'Invalid service' });
  const logMap = {
    alist: '/var/log/alist.log',
    rclone: '/var/log/rclone.log',
    nginx: '/var/log/nginx/error.log',
    api: '/var/log/api.log',
  };
  try {
    const lines = req.query.lines || 100;
    const log = execSync(`tail -n ${lines} ${logMap[service]} 2>/dev/null || echo "No logs available"`, {
      encoding: 'utf-8',
      timeout: 5000,
    });
    res.json({ service, log });
  } catch {
    res.json({ service, log: 'No logs available' });
  }
});

// Test remote connection
app.post('/api/rclone/test', authMiddleware, async (req, res) => {
  try {
    const { remote } = req.body;
    if (!remote) return res.status(400).json({ error: 'remote is required' });
    const start = Date.now();
    const fsPath = remote + ':';

    // Rclone RC API often returns 200 OK and empty list for invalid webdav/http configs
    // Therefore, using CLI commands directly is the most reliable way to catch connection errors.
    const util = require('util');
    const execPromise = util.promisify(exec);

    try {
      // Use lsf to list the first level of items. It will throw an error if connection fails.
      const { stdout } = await execPromise(`rclone lsf "${fsPath}" --max-depth 1 --config=/data/rclone/rclone.conf`, { timeout: 15000 });
      const elapsed = Date.now() - start;
      const count = stdout.split('\n').filter(line => line.trim().length > 0).length;
      res.json({ ok: true, message: `连接成功！响应耗时: ${elapsed}ms, 根目录可见 ${count} 个项目。` });
    } catch (err) {
      // Extract the actual error message from stderr
      const stderr = err.stderr || err.message || '';
      // Clean up the error message, usually rclone outputs "Failed to XXX: error body"
      const cleanError = stderr.split('\n').filter(l => l.includes('Failed to') || l.includes('error')).join('; ') || stderr;
      throw new Error(cleanError || '未知连接错误');
    }
  } catch (err) {
    res.json({ ok: false, message: '连接失败: ' + err.message });
  }
});

// ========================
// File Operations
// ========================
// List files in a remote path
app.post('/api/rclone/ls', authMiddleware, async (req, res) => {
  try {
    const { fs: remotePath, remote, path: dirPath } = req.body;
    // Rclone operations/list works best with "fs" as the remote root (e.g. "alist:") 
    // and "remote" as the subpath (e.g. "/path/to/folder")

    // Support two types of calls:
    // 1. fs="alist:/path", remote is unused
    // 2. fs="alist:", remote="/path"

    let fsStr = remotePath || remote;
    let remoteStr = dirPath || '';

    // If fs contains the full path (e.g., from frontend browse), split it
    if (fsStr && fsStr.includes(':') && !remoteStr) {
      const parts = fsStr.split(':');
      fsStr = parts[0] + ':';
      remoteStr = parts.slice(1).join(':').replace(/^\/+/, ''); // Remove leading slashes
    }

    if (!fsStr) return res.status(400).json({ error: 'fs or remote is required' });
    const result = await rcloneRC('/operations/list', { fs: fsStr, remote: remoteStr });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Copy files between remotes
app.post('/api/rclone/copy', authMiddleware, async (req, res) => {
  try {
    const { srcFs, dstFs, _async, _config, _filter } = req.body;
    if (!srcFs || !dstFs) return res.status(400).json({ error: 'srcFs and dstFs are required' });
    const params = { srcFs, dstFs, _async: _async !== false };
    if (_config) params._config = _config;
    if (_filter) params._filter = _filter;
    const result = await rcloneRC('/sync/copy', params);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Sync files between remotes
app.post('/api/rclone/sync', authMiddleware, async (req, res) => {
  try {
    const { srcFs, dstFs, _async, _config, _filter } = req.body;
    if (!srcFs || !dstFs) return res.status(400).json({ error: 'srcFs and dstFs are required' });
    const params = { srcFs, dstFs, _async: _async !== false };
    if (_config) params._config = _config;
    if (_filter) params._filter = _filter;
    const result = await rcloneRC('/sync/sync', params);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Move files between remotes
app.post('/api/rclone/move', authMiddleware, async (req, res) => {
  try {
    const { srcFs, dstFs, _async, _config, _filter } = req.body;
    if (!srcFs || !dstFs) return res.status(400).json({ error: 'srcFs and dstFs are required' });
    const params = { srcFs, dstFs, _async: _async !== false };
    if (_config) params._config = _config;
    if (_filter) params._filter = _filter;
    const result = await rcloneRC('/sync/move', params);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get transfer stats
app.get('/api/rclone/stats', authMiddleware, async (req, res) => {
  try {
    const result = await rcloneRC('/core/stats');
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// List running jobs
app.get('/api/rclone/jobs', authMiddleware, async (req, res) => {
  try {
    const result = await rcloneRC('/job/list');
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get job status
app.get('/api/rclone/job/:id', authMiddleware, async (req, res) => {
  try {
    const result = await rcloneRC('/job/status', { jobid: parseInt(req.params.id) });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Stop a job
app.post('/api/rclone/job/stop', authMiddleware, async (req, res) => {
  try {
    const { jobid } = req.body;
    const result = await rcloneRC('/job/stop', { jobid });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ========================
// Start Server
// ========================
app.listen(PORT, '127.0.0.1', () => {
  console.log(`API server running on http://127.0.0.1:${PORT}`);
});
