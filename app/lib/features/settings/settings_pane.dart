import '../../data/setting_key.dart';
import '../../data/setting_keys.dart';

/// The panes of the Settings view, in the order the list shows them.
enum SettingsPane {
  general('General'),
  fileTypes('File types'),
  saveTo('Save to'),
  downloads('Downloads'),
  connection('Connection'),
  proxy('Proxy'),
  siteLogins('Site logins'),
  notifications('Notifications and sounds'),
  appearance('Appearance'),
  about('About');

  const SettingsPane(this.title);
  final String title;

  /// The settings this pane owns, which "Reset this pane" puts back to their
  /// defaults. Settings kept in their own tables (categories, site rules,
  /// logins) are reset by their panes.
  List<SettingKey<Object?>> get keys => switch (this) {
    SettingsPane.general => [
      Keys.launchAtLogin,
      Keys.startHidden,
      Keys.resumeOnLaunch,
      Keys.keepAwake,
      Keys.browserIntegrationEnabled,
      Keys.bridgePort,
    ],
    SettingsPane.fileTypes => [
      Keys.interceptExtensions,
      Keys.interceptMinBytes,
    ],
    SettingsPane.saveTo => [
      Keys.defaultSaveDir,
      Keys.rememberLastFolderPerCategory,
    ],
    SettingsPane.downloads => [
      Keys.autoStartBrowserDownloads,
      Keys.maxConcurrentDownloads,
      Keys.duplicateAction,
      Keys.autoRemoveCompleted,
      Keys.defaultUserAgent,
    ],
    SettingsPane.connection => [
      Keys.maxConnections,
      Keys.speedLimitEnabled,
      Keys.speedLimitBytesPerSec,
      Keys.retryAttempts,
      Keys.stallTimeoutSeconds,
    ],
    SettingsPane.proxy => [
      Keys.proxyMode,
      Keys.proxyHost,
      Keys.proxyPort,
      Keys.proxyUsername,
      Keys.proxyBypass,
    ],
    SettingsPane.siteLogins => const [],
    SettingsPane.notifications => [
      Keys.notificationsEnabled,
      Keys.notifyOnComplete,
      Keys.notifyOnFailure,
      Keys.soundOnComplete,
      Keys.soundOnFailure,
      Keys.soundOnQueueFinished,
    ],
    SettingsPane.appearance => [
      Keys.themeMode,
      Keys.listDensity,
      Keys.showSpeedInMenuBar,
    ],
    SettingsPane.about => const [],
  };
}
