import 'dart:async';
import 'dart:math';

import 'package:download_engine/download_engine.dart';

import '../../data/categories_repository.dart';
import '../../data/downloads_repository.dart';
import '../../data/setting_keys.dart';
import '../../data/settings_repository.dart';
import '../../data/site_rules_repository.dart';
import 'bridge_payload.dart';
import 'bridge_server.dart';

/// What the app does with a download the browser hands over: it is stored
/// with the browser's cookies, referrer and user agent and joins the queue.
class BrowserIntake implements BridgeBackend {
  BrowserIntake({
    required this.downloads,
    required this.categories,
    required this.settings,
    required this.siteRules,
    String Function()? newId,
  }) : _newId = newId ?? _randomId;

  final DownloadsRepository downloads;
  final CategoriesRepository categories;
  final SettingsRepository settings;
  final SiteRulesRepository siteRules;
  final String Function() _newId;

  static final _rng = Random();
  static String _randomId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(1 << 32).toRadixString(36)}';

  /// Called instead of adding at once when "Start browser downloads at once"
  /// is off, so the person can look at it first. Without it, downloads are
  /// added straight away.
  Future<void> Function(String id, BridgePayload payload)? onAsk;

  /// Called after a download was added without asking, with its file name.
  void Function(String fileName)? onAdded;

  @override
  Future<String> accept(BridgePayload payload) async {
    final id = _newId();
    final ask = onAsk;
    if (ask == null || settings.get(Keys.autoStartBrowserDownloads)) {
      await add(id, payload);
      onAdded?.call(nameFor(payload));
    } else {
      // The extension is answered now; the person decides at their pace.
      unawaited(ask(id, payload));
    }
    return id;
  }

  /// Stores the download and starts it.
  Future<void> add(String id, BridgePayload payload) async {
    final name = nameFor(payload);
    final category = await categories.categoryFor(name);
    await downloads.add(
      DownloadRequest(
        id: id,
        url: payload.url,
        saveDir: category.saveDir,
        fileName: payload.fileName,
        referrer: payload.referrer,
        userAgent: payload.userAgent,
        cookies: payload.cookies,
        maxConnections: settings.get(Keys.maxConnections),
      ),
      source: payload.source,
      categoryId: category.id,
    );
  }

  /// The file name to sort by: what the browser said, else the end of the link.
  static String nameFor(BridgePayload payload) {
    final given = payload.fileName;
    if (given != null && given.isNotEmpty) return given;
    final segments = payload.url.pathSegments.where((s) => s.isNotEmpty);
    return segments.isEmpty ? '' : Uri.decodeComponent(segments.last);
  }

  @override
  Future<Map<String, Object?>> config() async => {
    'enabled': settings.get(Keys.browserIntegrationEnabled),
    'interceptExtensions': settings.get(Keys.interceptExtensions),
    'interceptMinBytes': settings.get(Keys.interceptMinBytes),
    'excludedHosts': await siteRules.excludedHosts(),
  };
}
