import 'dart:io';

import 'package:download_engine/download_engine.dart';

const _usage = '''
Usage: dart run bin/dl.dart <url> [-c connections] [-o folder]

  -c, --connections  Parallel connections, 1 to 16 (default 8)
  -o, --output       Folder to save into (default: current folder)
  -h, --help         Show this message
''';

Future<void> main(List<String> args) async {
  String? url;
  var connections = 8;
  var folder = Directory.current.path;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    switch (a) {
      case '-h' || '--help':
        stdout.write(_usage);
        return;
      case '-c' || '--connections':
        if (++i >= args.length) return _fail('Missing value for $a');
        final n = int.tryParse(args[i]);
        if (n == null || n < 1 || n > 16) {
          return _fail('Connections must be between 1 and 16');
        }
        connections = n;
      case '-o' || '--output':
        if (++i >= args.length) return _fail('Missing value for $a');
        folder = args[i];
      default:
        if (a.startsWith('-')) return _fail('Unknown option $a');
        if (url != null) return _fail('Only one URL at a time');
        url = a;
    }
  }
  if (url == null) {
    stderr.write(_usage);
    exitCode = 64;
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return _fail('Not an http(s) URL: $url');
  }

  final client = HttpClient()
    ..autoUncompress = false
    ..maxConnectionsPerHost = connections > 6 ? connections : 6;

  final task = DownloadTask(
    client: client,
    snapshot: DownloadSnapshot(
      request: DownloadRequest(
        id: 'cli',
        url: uri,
        saveDir: folder,
        maxConnections: connections,
      ),
    ),
  );

  ProgressEvent? last;
  task.events.listen((e) {
    if (e is ProgressEvent) last = e;
    if (e is SnapshotEvent && e.snapshot.status == DownloadStatus.probing) {
      stdout.writeln('Connecting to ${uri.host}...');
    }
  });

  // One line per second, whatever the engine's own event rate is.
  final ticker = Stream<void>.periodic(const Duration(seconds: 1)).listen((_) {
    final p = last;
    if (p != null) stdout.writeln(_line(p));
  });

  final result = await task.run();
  await ticker.cancel();
  client.close(force: true);

  if (result.status == DownloadStatus.completed) {
    stdout.writeln(
      'Done: ${result.finalPath} (${_size(result.totalBytes ?? 0)}, '
      '${result.segments.length} segments)',
    );
  } else {
    stderr.writeln('Failed: ${result.error?.message ?? result.status.name}');
    exitCode = 1;
  }
}

void _fail(String message) {
  stderr
    ..writeln(message)
    ..write(_usage);
  exitCode = 64;
}

String _line(ProgressEvent p) {
  final total = p.totalBytes;
  final pct = total == null || total == 0
      ? '  ?%'
      : '${(p.downloadedBytes * 100 ~/ total).toString().padLeft(3)}%';
  final active = p.segmentBytes.length;
  final eta = p.eta == null ? '--' : _duration(p.eta!);
  return '$pct  ${_size(p.downloadedBytes)}'
      '${total == null ? '' : ' / ${_size(total)}'}  '
      '${_size(p.bytesPerSecond.round())}/s  ETA $eta  ($active segments)';
}

String _size(int bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

String _duration(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}
