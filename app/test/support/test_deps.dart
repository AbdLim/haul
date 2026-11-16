import 'dart:io';

import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:haul/app/dependencies.dart';
import 'package:haul/data/categories_repository.dart';
import 'package:haul/services/bridge/bridge_controller.dart';
import 'package:haul/services/bridge/browser_intake.dart';
import 'package:haul/data/database.dart';
import 'package:haul/data/downloads_repository.dart';
import 'package:haul/data/network_sync.dart';
import 'package:haul/data/settings_engine_sync.dart';
import 'package:haul/data/settings_repository.dart';
import 'package:haul/data/site_logins_repository.dart';
import 'package:haul/data/site_rules_repository.dart';
import 'package:haul/services/network/proxy_tester.dart';
import 'package:haul/services/network/system_proxy.dart';
import 'package:haul/services/network/url_prober.dart';
import 'package:haul/services/system/app_window.dart';
import 'package:haul/services/system/folder_picker.dart';
import 'package:haul/services/system/login_item.dart';
import 'package:haul/services/system/notifier.dart';
import 'package:haul/services/system/sleep_blocker.dart';
import 'package:haul/services/system/tray_host.dart';
import 'package:haul/services/system/platform_services.dart';
import 'package:haul/services/system/secret_store.dart';
import 'package:haul/services/system/sound_player.dart';
import 'package:haul/services/system/window_chrome.dart';

/// An engine that records commands and lets a test push events in.
class FakeEngine implements EngineApi {
  final controller = StreamController<EngineEvent>.broadcast();
  final commands = <EngineCommand>[];

  @override
  Stream<EngineEvent> get events => controller.stream;
  @override
  void send(EngineCommand command) => commands.add(command);
  @override
  Future<void> dispose() async {}

  void emit(EngineEvent e) => controller.add(e);
}

/// Answers for links by looking them up, instantly.
class FakeUrlProber implements UrlProber {
  final answers = <String, UrlInfo>{};
  final failures = <String, String>{};
  final calls = <Uri>[];
  final headers = <({String? referrer, String? cookies, String? userAgent})>[];

  @override
  Future<UrlInfo> probe(
    Uri url, {
    String? referrer,
    String? cookies,
    String? userAgent,
  }) async {
    headers.add((referrer: referrer, cookies: cookies, userAgent: userAgent));
    calls.add(url);
    final fail = failures[url.toString()];
    if (fail != null) throw UrlProbeException(fail);
    return answers[url.toString()] ??
        UrlInfo(
          fileName: url.pathSegments.isEmpty
              ? 'download'
              : url.pathSegments.last,
          supportsRanges: true,
        );
  }
}

/// A proxy test whose outcome the test chooses.
class FakeProxyTester implements ProxyTester {
  ProxyTestResult result = const ProxyTestResult.ok();
  final tested = <ProxyConfig>[];

  @override
  Future<ProxyTestResult> test(ProxyConfig proxy) async {
    tested.add(proxy);
    return result;
  }
}

/// The Mac's proxy, as the test says it is.
class FakeSystemProxy implements SystemProxyResolver {
  ProxyConfig? proxy;

  @override
  Future<ProxyConfig?> resolve() async => proxy;
}

/// Records the sounds asked for.
class FakeSoundPlayer implements SoundPlayer {
  final played = <String>[];

  @override
  Future<List<String>> names() async => ['Glass', 'Hero', 'Ping'];

  @override
  Future<bool> play(String name) async {
    played.add(name);
    return true;
  }
}

class FakeFolderPicker implements FolderPicker {
  String? next;

  @override
  Future<String?> pick({String? startIn}) async => next;
}

/// Records what the app asked the system to do.
class FakePlatform extends PlatformServices {
  FakePlatform();

  final revealed = <String>[];
  final opened = <String>[];
  final trashed = <String>[];

  @override
  Future<Directory> defaultDownloadDirectory() async =>
      Directory('/Users/test/Downloads');
  @override
  Future<Directory> appSupportDirectory() async =>
      Directory('/tmp/haul-test-support');
  @override
  Future<void> revealInFileManager(String path) async => revealed.add(path);
  @override
  Future<void> openFile(String path) async => opened.add(path);
  @override
  Future<void> moveToTrash(String path) async => trashed.add(path);
}

/// Everything the UI needs, in memory.
Future<({AppDependencies deps, FakeEngine engine, NoWindowChrome chrome})>
makeTestDeps({
  String downloadsDir = '/Users/test/Downloads',

  /// Gives the app a browser bridge that tries this port (0 = any free one).
  int? bridgePort,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = HaulDatabase.inMemory();
  final settings = await SettingsRepository.open(db);
  await settings.ensureBridgeToken();
  final categories = CategoriesRepository(db);
  await categories.ensureBuiltIns(downloadsDir);
  final engine = FakeEngine();
  final chrome = NoWindowChrome();
  final secrets = MemorySecretStore();
  final siteRules = SiteRulesRepository(db);
  final siteLogins = SiteLoginsRepository(db, secrets);
  final downloads = DownloadsRepository(
    engine: engine,
    database: db,
    saveInterval: const Duration(milliseconds: 50),
  );
  final systemProxy = FakeSystemProxy();
  final intake = BrowserIntake(
    downloads: downloads,
    categories: categories,
    settings: settings,
    siteRules: siteRules,
  );
  final deps = AppDependencies(
    database: db,
    settings: settings,
    categories: categories,
    siteRules: siteRules,
    siteLogins: siteLogins,
    downloads: downloads,
    networkSync: NetworkSync(
      settings: settings,
      secrets: secrets,
      logins: siteLogins,
      rules: siteRules,
      downloads: downloads,
      systemProxy: systemProxy,
      delay: const Duration(milliseconds: 20),
    ),
    limitsSync: SettingsEngineSync(settings, downloads),
    proxyTester: FakeProxyTester(),
    sounds: FakeSoundPlayer(),
    window: FakeAppWindow(),
    notifier: FakeNotifier(),
    tray: FakeTrayHost(),
    loginItem: FakeLoginItem(),
    sleepBlocker: FakeSleepBlocker(),
    intake: intake,
    bridge: bridgePort == null
        ? null
        : BridgeController(
            settings: settings,
            portOverride: bridgePort,
            backend: intake,
          ),
    systemProxy: systemProxy,
    platform: FakePlatform(),
    chrome: chrome,
    secrets: secrets,
    urlProber: FakeUrlProber(),
    folderPicker: FakeFolderPicker(),
  );
  return (deps: deps, engine: engine, chrome: chrome);
}
