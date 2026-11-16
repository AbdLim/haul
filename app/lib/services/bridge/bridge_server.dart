import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'bridge_payload.dart';

/// What the bridge does with what the extension sends.
abstract class BridgeBackend {
  /// Takes a download. Returns its id.
  Future<String> accept(BridgePayload payload);

  /// The lists the extension follows (`GET /v1/config`).
  Future<Map<String, Object?>> config();
}

/// The largest body the bridge reads.
const maxBridgeBody = 256 * 1024;

/// A web server on this Mac's loopback address only, for the browser
/// extension. Routes: GET /v1/ping, GET /v1/config and
/// POST /v1/downloads.
class BridgeServer {
  BridgeServer._(this._server, this._token, this._backend, this._version) {
    _sub = _server.listen(_handle);
  }

  final HttpServer _server;
  final String? Function() _token;
  final BridgeBackend _backend;
  final String _version;
  late final StreamSubscription<HttpRequest> _sub;

  /// Called after a request that carried the right token, so the app can tell
  /// a browser is paired.
  void Function()? onAuthenticated;

  /// Starts listening on `127.0.0.1:[port]` (0 picks a free one). Throws a
  /// [SocketException] if the port is taken.
  static Future<BridgeServer> start({
    required int port,
    required String? Function() token,
    required BridgeBackend backend,
    required String version,
    void Function()? onAuthenticated,
  }) async {
    // IPv4 loopback only, never every interface.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    return BridgeServer._(server, token, backend, version)
      ..onAuthenticated = onAuthenticated;
  }

  int get port => _server.port;

  InternetAddress get address => _server.address;

  Future<void> close() async {
    await _sub.cancel();
    await _server.close(force: true);
  }

  // -- requests --------------------------------------------------------------

  Future<void> _handle(HttpRequest request) async {
    try {
      await _route(request);
    } on Object {
      await _reply(request, HttpStatus.internalServerError, {
        'error': 'Something went wrong',
      });
    }
  }

  Future<void> _route(HttpRequest request) async {
    // A web page can send a request here, but it cannot choose the Host a
    // name resolves to: a rebinding attack arrives with its own host name.
    if (!_hostAllowed(request.headers.value(HttpHeaders.hostHeader))) {
      return _reply(request, HttpStatus.forbidden, {'error': 'Bad host'});
    }
    final path = request.uri.path;
    final method = request.method;

    if (path == '/v1/ping') {
      if (method != 'GET') return _methodNotAllowed(request, 'GET');
      return _reply(request, HttpStatus.ok, {
        'app': 'Haul',
        'version': _version,
        'protocol': 1,
      });
    }
    if (path == '/v1/downloads') {
      if (method != 'POST') return _methodNotAllowed(request, 'POST');
      if (!_tokenOk(request)) return _unauthorised(request);
      return _postDownload(request);
    }
    if (path == '/v1/config') {
      if (method != 'GET') return _methodNotAllowed(request, 'GET');
      if (!_tokenOk(request)) return _unauthorised(request);
      onAuthenticated?.call();
      return _reply(request, HttpStatus.ok, await _backend.config());
    }
    return _reply(request, HttpStatus.notFound, {'error': 'Not found'});
  }

  bool _hostAllowed(String? host) {
    if (host == null) return false;
    final p = port;
    return host == '127.0.0.1:$p' || host == 'localhost:$p';
  }

  bool _tokenOk(HttpRequest request) {
    final expected = _token();
    final given = request.headers.value('X-Bridge-Token');
    if (expected == null || expected.isEmpty || given == null) return false;
    return constantTimeEquals(expected, given);
  }

  Future<void> _postDownload(HttpRequest request) async {
    final declared = request.contentLength;
    if (declared > maxBridgeBody) return _tooLarge(request);
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > maxBridgeBody) return _tooLarge(request);
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return _reply(request, HttpStatus.badRequest, {
        'error': 'The body is not valid JSON',
      });
    }
    final BridgePayload payload;
    try {
      payload = BridgePayload.parse(json);
    } on BadPayload catch (e) {
      return _reply(request, HttpStatus.badRequest, {'error': e.message});
    } on UnsupportedLink catch (e) {
      return _reply(request, HttpStatus.unprocessableEntity, {
        'error': e.message,
      });
    }
    onAuthenticated?.call();
    final id = await _backend.accept(payload);
    return _reply(request, HttpStatus.accepted, {'id': id});
  }

  Future<void> _tooLarge(HttpRequest request) async {
    await _reply(request, HttpStatus.requestEntityTooLarge, {
      'error': 'The body is over 256 KB',
    }, close: true);
  }

  Future<void> _unauthorised(HttpRequest request) => _reply(
    request,
    HttpStatus.unauthorized,
    {'error': 'Missing or wrong token'},
  );

  Future<void> _methodNotAllowed(HttpRequest request, String allow) => _reply(
    request,
    HttpStatus.methodNotAllowed,
    {'error': 'Use $allow'},
    headers: {HttpHeaders.allowHeader: allow},
  );

  /// Sends JSON. No CORS headers are ever added, so a web page cannot read
  /// the answer.
  Future<void> _reply(
    HttpRequest request,
    int status,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
    bool close = false,
  }) async {
    final response = request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json;
    headers.forEach(response.headers.set);
    if (close) response.headers.set(HttpHeaders.connectionHeader, 'close');
    response.write(jsonEncode(body));
    await response.close();
  }
}

/// Compares two strings in time that does not depend on where they differ.
bool constantTimeEquals(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  var diff = x.length ^ y.length;
  final n = x.length > y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    diff |= (i < x.length ? x[i] : 0) ^ (i < y.length ? y[i] : 0);
  }
  return diff == 0;
}
