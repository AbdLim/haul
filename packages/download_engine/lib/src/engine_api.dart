import 'dart:async';

import 'models/commands.dart';
import 'models/download_request.dart';
import 'models/download_snapshot.dart';
import 'models/events.dart';
import 'models/network_config.dart';

/// What the app sees of the engine: commands in, one event stream out.
///
/// `DownloadEngine` runs in the caller's isolate; `IsolateEngine` runs the
/// same engine in a background isolate. Both implement this.
abstract interface class EngineApi {
  /// Every snapshot, progress and file-changed event, for all downloads.
  Stream<EngineEvent> get events;

  /// Queues a command. Commands are applied in order.
  void send(EngineCommand command);

  /// Stops all transfers (keeping partial files) and releases resources.
  Future<void> dispose();
}

/// Typed shortcuts for the commands.
extension EngineCommands on EngineApi {
  void add(DownloadRequest request, {DownloadSnapshot? snapshot}) =>
      send(AddCommand(request, snapshot: snapshot));

  void pause(String id) => send(PauseCommand(id));
  void resume(String id) => send(ResumeCommand(id));
  void cancel(String id) => send(CancelCommand(id));
  void remove(String id) => send(RemoveCommand(id));

  void refreshUrl(
    String id,
    Uri url, {
    String? referrer,
    String? cookies,
    String? userAgent,
  }) => send(
    RefreshUrlCommand(
      id,
      url,
      referrer: referrer,
      cookies: cookies,
      userAgent: userAgent,
    ),
  );

  void setNetwork(NetworkConfig config) => send(SetNetworkCommand(config));

  void setLimits({
    int? maxConcurrentDownloads,
    int? maxConnections,
    int? speedLimitBytesPerSec,
  }) => send(
    SetLimitsCommand(
      maxConcurrentDownloads: maxConcurrentDownloads,
      maxConnections: maxConnections,
      speedLimitBytesPerSec: speedLimitBytesPerSec,
    ),
  );
}
