// A stand-in for the Haul app's bridge, with the same routes and answers.
const http = require('node:http');

function startMockBridge({ token = 'secret', accept = true, log = [] } = {}) {
  // Tests change these to act as the person editing Haul's Settings.
  const config = {
    enabled: true,
    interceptExtensions: ['zip'],
    interceptMinBytes: 1048576,
    excludedHosts: ['blocked.example'],
  };
  const server = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => { body += c; });
    req.on('end', () => {
      const entry = { method: req.method, url: req.url, token: req.headers['x-bridge-token'], body };
      log.push(entry);
      const send = (status, json) => {
        res.writeHead(status, { 'content-type': 'application/json' });
        res.end(JSON.stringify(json));
      };
      if (req.url === '/v1/ping') return send(200, { app: 'Haul', version: '1.0.0', protocol: 1 });
      if (req.headers['x-bridge-token'] !== token) return send(401, { error: 'Missing or wrong token' });
      if (req.url === '/v1/config') {
        return send(200, config);
      }
      if (req.url === '/v1/downloads' && req.method === 'POST') {
        return accept ? send(202, { id: `id-${log.length}` }) : send(422, { error: 'no' });
      }
      return send(404, { error: 'Not found' });
    });
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      resolve({ server, config, port: server.address().port, log, close: () => new Promise((r) => { server.closeAllConnections(); server.close(r); }) });
    });
  });
}

module.exports = { startMockBridge };
