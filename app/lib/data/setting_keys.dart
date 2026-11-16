import 'setting_key.dart';

enum AppThemeMode { system, dark, light }

enum ListDensity { comfortable, compact }

/// What to do when a URL that is already in the list is added again.
enum DuplicateAction { ask, numberedCopy, resumeExisting }

/// When to drop finished downloads from the list.
enum AutoRemove { never, onQuit, afterSevenDays }

enum ProxyMode { none, system, manual }

/// The extensions Haul takes over from browsers, unless the user changes
/// them.
const defaultInterceptExtensions = [
  'zip', 'rar', '7z', 'tar', 'gz', 'dmg', 'pkg', 'iso', 'exe', 'msi', 'apk',
  'mp4', 'mkv', 'mov', 'avi', 'mp3', 'flac', 'wav', 'pdf', 'epub', //
];

/// Every setting, with its default. Keys are stable: they are the names
/// stored in the database.
abstract final class Keys {
  // General
  static final defaultSaveDir = SettingKey.optionalString('defaultSaveDir');
  static final launchAtLogin = SettingKey.boolean('launchAtLogin', false);
  static final startHidden = SettingKey.boolean('startHidden', false);
  static final resumeOnLaunch = SettingKey.boolean('resumeOnLaunch', true);
  static final keepAwake = SettingKey.boolean('keepAwake', true);

  // Browser integration
  static final browserIntegrationEnabled = SettingKey.boolean(
    'browserIntegrationEnabled',
    true,
  );
  static final bridgePort = SettingKey.integer('bridgePort', 47821);

  /// Null until the bridge generates one on first launch.
  static final bridgeToken = SettingKey.optionalString('bridgeToken');
  static final autoStartBrowserDownloads = SettingKey.boolean(
    'autoStartBrowserDownloads',
    false,
  );

  // File types
  static final interceptExtensions = SettingKey.stringList(
    'interceptExtensions',
    defaultInterceptExtensions,
  );
  static final interceptMinBytes = SettingKey.integer(
    'interceptMinBytes',
    1048576,
  );

  // Save to
  static final rememberLastFolderPerCategory = SettingKey.boolean(
    'rememberLastFolderPerCategory',
    false,
  );

  // Downloads
  static final maxConcurrentDownloads = SettingKey.integer(
    'maxConcurrentDownloads',
    3,
  );
  static final duplicateAction = SettingKey.enumeration(
    'duplicateAction',
    DuplicateAction.values,
    DuplicateAction.ask,
  );
  static final autoRemoveCompleted = SettingKey.enumeration(
    'autoRemoveCompleted',
    AutoRemove.values,
    AutoRemove.never,
  );
  static final defaultUserAgent = SettingKey.optionalString('defaultUserAgent');

  // Connection
  static final maxConnections = SettingKey.integer('maxConnections', 8);
  static final speedLimitEnabled = SettingKey.boolean(
    'speedLimitEnabled',
    false,
  );
  static final speedLimitBytesPerSec = SettingKey.integer(
    'speedLimitBytesPerSec',
    0,
  );
  static final retryAttempts = SettingKey.integer('retryAttempts', 8);
  static final stallTimeoutSeconds = SettingKey.integer(
    'stallTimeoutSeconds',
    30,
  );

  // Proxy (the password lives in the Keychain, never here)
  static final proxyMode = SettingKey.enumeration(
    'proxyMode',
    ProxyMode.values,
    ProxyMode.none,
  );
  static final proxyHost = SettingKey.optionalString('proxyHost');
  static final proxyPort = SettingKey.optionalInt('proxyPort');
  static final proxyUsername = SettingKey.optionalString('proxyUsername');
  static final proxyBypass = SettingKey.stringList('proxyBypass', const []);

  // Notifications and sounds
  static final notificationsEnabled = SettingKey.boolean(
    'notificationsEnabled',
    true,
  );
  static final notifyOnComplete = SettingKey.boolean('notifyOnComplete', true);
  static final notifyOnFailure = SettingKey.boolean('notifyOnFailure', true);
  static final soundOnComplete = SettingKey.optionalString('soundOnComplete');
  static final soundOnFailure = SettingKey.optionalString('soundOnFailure');
  static final soundOnQueueFinished = SettingKey.optionalString(
    'soundOnQueueFinished',
  );

  // Appearance
  static final themeMode = SettingKey.enumeration(
    'themeMode',
    AppThemeMode.values,
    AppThemeMode.system,
  );
  static final listDensity = SettingKey.enumeration(
    'listDensity',
    ListDensity.values,
    ListDensity.comfortable,
  );
  static final showSpeedInMenuBar = SettingKey.boolean(
    'showSpeedInMenuBar',
    true,
  );

  /// The first-run card was closed, or a browser has connected. Not a
  /// preference, so it is not in [all]: "Reset all settings" does not bring
  /// the card back.
  static final firstRunDismissed = SettingKey.boolean(
    'firstRunDismissed',
    false,
  );

  /// Look for a newer Haul on GitHub once a day.
  static final checkForUpdates = SettingKey.boolean('checkForUpdates', true);

  /// When the last check ran, in seconds since 1970. Not a preference, so it is
  /// not in [all].
  static final lastUpdateCheck = SettingKey.optionalInt('lastUpdateCheck');

  /// A version the person chose to skip: its banner stays away.
  static final skippedUpdate = SettingKey.optionalString('skippedUpdate');

  /// Every key, for "reset all settings" and for tests.
  static final List<SettingKey<Object?>> all = [
    defaultSaveDir, launchAtLogin, startHidden, resumeOnLaunch, keepAwake,
    browserIntegrationEnabled, bridgePort, bridgeToken,
    autoStartBrowserDownloads, interceptExtensions, interceptMinBytes,
    rememberLastFolderPerCategory, maxConcurrentDownloads, duplicateAction,
    autoRemoveCompleted, defaultUserAgent, maxConnections, speedLimitEnabled,
    speedLimitBytesPerSec, retryAttempts, stallTimeoutSeconds, proxyMode,
    proxyHost, proxyPort, proxyUsername, proxyBypass, notificationsEnabled,
    notifyOnComplete, notifyOnFailure, soundOnComplete, soundOnFailure,
    soundOnQueueFinished, themeMode, listDensity, showSpeedInMenuBar,
    checkForUpdates, skippedUpdate, //
  ];
}
