import 'package:download_engine/download_engine.dart';

import 'engine_suite.dart';

void main() {
  // The very same suite, against the engine running in another isolate.
  runEngineSuite('IsolateEngine', ({required int concurrent}) {
    return IsolateEngine.start(
      maxConcurrentDownloads: concurrent,
      retryDelays: const [Duration.zero],
    );
  });
}
