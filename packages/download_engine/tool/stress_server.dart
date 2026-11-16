// A slow local file server for trying Haul with many active downloads at once.
//
//   cd packages/download_engine
//   dart run tool/stress_server.dart            # one 4 GiB file at 1 MiB/s
//   dart run tool/stress_server.dart 20         # prints 20 different links
//
// Paste the links into Haul (or drag a text file holding them onto the
// window). Press Ctrl-C to stop. Every link is a different path that
// redirects to the same file, so Haul treats each as its own download.
import 'dart:io';

import '../test_support/range_server.dart';

Future<void> main(List<String> args) async {
  final count = args.isEmpty ? 1 : int.parse(args.first);
  final server = await RangeServer.start(
    size: 4 * 1024 * 1024 * 1024,
    throttleBytesPerSec: 1024 * 1024,
  );
  stdout.writeln(
    'Serving $count link${count == 1 ? '' : 's'}. Ctrl-C to stop.',
  );
  for (var i = 1; i <= count; i++) {
    // Each link redirects to the one file, so Haul sees different links.
    stdout.writeln(
      server.redirectFrom('/stress-${i.toString().padLeft(2, '0')}.bin'),
    );
  }
  await ProcessSignal.sigint.watch().first;
  await server.close();
}
