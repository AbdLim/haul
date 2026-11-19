import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:path/path.dart' as p;

import '../data/categories_repository.dart';
import '../data/database.dart';
import '../data/downloads_repository.dart';
import '../data/setting_keys.dart';
import '../data/network_sync.dart';
import '../data/settings_engine_sync.dart';
import '../data/settings_repository.dart';
import '../data/site_logins_repository.dart';
import '../data/site_rules_repository.dart';
import '../services/bridge/bridge_controller.dart';
import '../services/bridge/browser_intake.dart';
import '../services/network/proxy_tester.dart';
import '../services/network/system_proxy.dart';
import '../services/network/url_prober.dart';
import '../services/system/app_window.dart';
import '../services/updates/update_checker.dart';
import '../services/system/folder_picker.dart';
import '../services/system/login_item.dart';
import '../services/system/notifier.dart';
import '../services/system/sleep_blocker.dart';
import '../services/system/tray_host.dart';
import '../services/system/platform_services.dart';
import '../services/system/sound_player.dart';
import '../services/system/secret_store.dart';
import '../services/system/window_chrome.dart';

/// Everything the UI needs, created once and passed down. Cubits get what
/// they need from here, so tests can build the same thing with fakes.
class AppDependencies {
  AppDependencies({
    required this.database,
    required this.settings,
    required this.categories,
    required this.siteRules,
    required this.siteLogins,
    required this.downloads,
    required this.platform,
    required this.chrome,
    required this.secrets,
    required this.urlProber,
    required this.folderPicker,
    this.limitsSync,
    this.networkSync,
    this.proxyTester,
    this.systemProxy,
    this.sounds,
    this.window,
    this.notifier,
    this.tray,
    this.loginItem,
    this.sleepBlocker,
    this.bridge,
    this.intake,
    this.updateSource,
  });

  final HaulDatabase database;
  final SettingsRepository settings;
  final CategoriesRepository categories;
  final SiteRulesRepository siteRules;
  final SiteLoginsRepository siteLogins;
  final DownloadsRepository downloads;
  final PlatformServices platform;
  final WindowChrome chrome;
  final SecretStore secrets;
  final UrlProber urlProber;
  final FolderPicker folderPicker;
  final SettingsEngineSync? limitsSync;
  final NetworkSync? networkSync;
  final ProxyTester? proxyTester;
  final SystemProxyResolver? systemProxy;
  final SoundPlayer? sounds;
  final AppWindow? window;
  final Notifier? notifier;
  final TrayHost? tray;
  final LoginItem? loginItem;
  final SleepBlocker? sleepBlocker;

  /// The local server the browser extension talks to.
  final BridgeController? bridge;

  /// What the bridge does with a download from the browser.
  final BrowserIntake? intake;

  /// Where Haul learns about newer versions.
  final UpdateSource? updateSource;

  /// The real thing: file database in the app support folder, the engine in
  /// its own isolate, and the platform's secret store.
  static Future<AppDependencies> start() async {
    final platform = PlatformServices.current;
    final chrome = WindowChrome.current;
    final window = AppWindow.current;
    await chrome.setup(hasSavedFrame: await window.hasSavedFrame());

    final support = await platform.appSupportDirectory();
    final database = HaulDatabase.file(
      File(p.join(support.path, 'haul.sqlite')),
    );
    final settings = await SettingsRepository.open(database);
    await settings.ensureBridgeToken();
    final secrets = SecureStorageSecretStore();

    final downloadsDir =
        settings.get(Keys.defaultSaveDir) ??
        (await platform.defaultDownloadDirectory()).path;
    final categories = CategoriesRepository(database);
    await categories.ensureBuiltIns(downloadsDir);

    final engine = await IsolateEngine.start(
      maxConcurrentDownloads: settings.get(Keys.maxConcurrentDownloads),
      stallTimeout: Duration(seconds: settings.get(Keys.stallTimeoutSeconds)),
      maxFailures: settings.get(Keys.retryAttempts),
    );
    final downloads = DownloadsRepository(engine: engine, database: database);
    final sync = SettingsEngineSync(settings, downloads);
    final siteRules = SiteRulesRepository(database);
    final siteLogins = SiteLoginsRepository(database, secrets);
    final systemProxy = SystemProxyResolver.current;
    final network = NetworkSync(
      settings: settings,
      secrets: secrets,
      logins: siteLogins,
      rules: siteRules,
      downloads: downloads,
      systemProxy: systemProxy,
    );
    final intake = BrowserIntake(
      downloads: downloads,
      categories: categories,
      settings: settings,
      siteRules: siteRules,
    );
    final bridge = BridgeController(settings: settings, backend: intake);
    await downloads.recover(
      resumeOnLaunch: settings.get(Keys.resumeOnLaunch),
      autoRemove: settings.get(Keys.autoRemoveCompleted),
    );

    // After recover: the browser must never find a half-started app.
    await bridge.start();

    return AppDependencies(
      database: database,
      settings: settings,
      categories: categories,
      siteRules: siteRules,
      siteLogins: siteLogins,
      downloads: downloads,
      platform: platform,
      chrome: chrome,
      secrets: secrets,
      urlProber: EngineUrlProber(network: () => network.latest),
      folderPicker: const SystemFolderPicker(),
      limitsSync: sync,
      networkSync: network,
      proxyTester: EngineProxyTester(),
      systemProxy: systemProxy,
      sounds: SoundPlayer.current,
      window: window,
      notifier: Notifier.current,
      tray: TrayHost.current,
      loginItem: LoginItem.current,
      sleepBlocker: SleepBlocker.current,
      bridge: bridge,
      intake: intake,
      updateSource: GitHubUpdateChecker(),
    );
  }

  /// Stops downloads (keeping partial files) and closes the database.
  Future<void> dispose() async {
    await bridge?.close();
    await limitsSync?.dispose();
    await networkSync?.dispose();
    await downloads.dispose();
    await settings.dispose();
    await database.close();
  }
}
