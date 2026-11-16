import 'download_request.dart';
import 'download_snapshot.dart';
import 'network_config.dart';

/// A message from the app to the engine. Plain data, so it can cross an
/// isolate boundary as JSON.
sealed class EngineCommand {
  const EngineCommand();

  Map<String, Object?> toJson();

  factory EngineCommand.fromJson(Map<String, Object?> json) {
    switch (json['type']! as String) {
      case 'add':
        return AddCommand(
          DownloadRequest.fromJson(json['request']! as Map<String, Object?>),
          snapshot: json['snapshot'] == null
              ? null
              : DownloadSnapshot.fromJson(
                  json['snapshot']! as Map<String, Object?>,
                ),
        );
      case 'pause':
        return PauseCommand(json['id']! as String);
      case 'resume':
        return ResumeCommand(json['id']! as String);
      case 'cancel':
        return CancelCommand(json['id']! as String);
      case 'remove':
        return RemoveCommand(json['id']! as String);
      case 'refreshUrl':
        return RefreshUrlCommand(
          json['id']! as String,
          Uri.parse(json['url']! as String),
          referrer: json['referrer'] as String?,
          cookies: json['cookies'] as String?,
          userAgent: json['userAgent'] as String?,
        );
      case 'setNetwork':
        return SetNetworkCommand(
          NetworkConfig.fromJson(json['config']! as Map<String, Object?>),
        );
      case 'setLimits':
        return SetLimitsCommand(
          maxConcurrentDownloads: json['maxConcurrentDownloads'] as int?,
          maxConnections: json['maxConnections'] as int?,
          speedLimitBytesPerSec: json['speedLimitBytesPerSec'] as int?,
        );
      default:
        throw FormatException('Unknown command type: ${json['type']}');
    }
  }
}

/// Adds a download. Pass [snapshot] to restore one saved earlier; it comes
/// back paused until a [ResumeCommand] arrives.
class AddCommand extends EngineCommand {
  const AddCommand(this.request, {this.snapshot});
  final DownloadRequest request;
  final DownloadSnapshot? snapshot;

  @override
  Map<String, Object?> toJson() => {
    'type': 'add',
    'request': request.toJson(),
    'snapshot': snapshot?.toJson(),
  };
}

class PauseCommand extends EngineCommand {
  const PauseCommand(this.id);
  final String id;
  @override
  Map<String, Object?> toJson() => {'type': 'pause', 'id': id};
}

class ResumeCommand extends EngineCommand {
  const ResumeCommand(this.id);
  final String id;
  @override
  Map<String, Object?> toJson() => {'type': 'resume', 'id': id};
}

/// Stops the download and deletes its `.part` file. The download is
/// dropped from the engine.
class CancelCommand extends EngineCommand {
  const CancelCommand(this.id);
  final String id;
  @override
  Map<String, Object?> toJson() => {'type': 'cancel', 'id': id};
}

/// Forgets a finished or paused download without touching the final file.
class RemoveCommand extends EngineCommand {
  const RemoveCommand(this.id);
  final String id;
  @override
  Map<String, Object?> toJson() => {'type': 'remove', 'id': id};
}

/// Replaces the URL (and optionally headers) of a download in
/// `needsRefresh`, then resumes it with the same segments.
class RefreshUrlCommand extends EngineCommand {
  const RefreshUrlCommand(
    this.id,
    this.url, {
    this.referrer,
    this.cookies,
    this.userAgent,
  });
  final String id;
  final Uri url;
  final String? referrer;
  final String? cookies;
  final String? userAgent;

  @override
  Map<String, Object?> toJson() => {
    'type': 'refreshUrl',
    'id': id,
    'url': url.toString(),
    'referrer': referrer,
    'cookies': cookies,
    'userAgent': userAgent,
  };
}

/// Null fields are left unchanged. A speed limit of 0 means unlimited.
class SetLimitsCommand extends EngineCommand {
  const SetLimitsCommand({
    this.maxConcurrentDownloads,
    this.maxConnections,
    this.speedLimitBytesPerSec,
  });
  final int? maxConcurrentDownloads;
  final int? maxConnections;
  final int? speedLimitBytesPerSec;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setLimits',
    'maxConcurrentDownloads': maxConcurrentDownloads,
    'maxConnections': maxConnections,
    'speedLimitBytesPerSec': speedLimitBytesPerSec,
  };
}

/// Replaces the engine's network configuration (proxy, site logins, per-site
/// limits, default user agent). It applies to requests made afterwards;
/// running workers finish their current request first.
class SetNetworkCommand extends EngineCommand {
  const SetNetworkCommand(this.config);
  final NetworkConfig config;

  @override
  Map<String, Object?> toJson() => {
    'type': 'setNetwork',
    'config': config.toJson(),
  };
}
