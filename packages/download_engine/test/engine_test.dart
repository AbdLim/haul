import 'package:download_engine/download_engine.dart';

import 'engine_suite.dart';

void main() {
  runEngineSuite('DownloadEngine', ({required int concurrent}) async {
    return DownloadEngine(
      maxConcurrentDownloads: concurrent,
      retryDelays: const [Duration.zero],
    );
  });
}
