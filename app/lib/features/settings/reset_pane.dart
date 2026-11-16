import '../../app/dependencies.dart';
import '../../data/setting_keys.dart';
import '../../data/site_rules_repository.dart';
import '../../services/system/secret_store.dart';
import 'settings_pane.dart';

/// "Reset this pane": the pane's own settings, and what it keeps in tables of
/// its own (category folders and extensions, the never-take-over sites).
Future<void> resetPane(AppDependencies deps, SettingsPane pane) async {
  await deps.settings.reset(pane.keys);
  switch (pane) {
    case SettingsPane.saveTo:
      final dir =
          deps.settings.get(Keys.defaultSaveDir) ??
          (await deps.platform.defaultDownloadDirectory()).path;
      for (final c in await deps.categories.all()) {
        if (c.builtIn) await deps.categories.resetBuiltIn(c.id, dir);
      }
    case SettingsPane.fileTypes:
      for (final r in await deps.siteRules.all()) {
        if (r.neverIntercept) {
          await deps.siteRules.save(
            SiteRule(host: r.host, maxConnections: r.maxConnections),
          );
        }
      }
    case SettingsPane.proxy:
      await deps.secrets.delete(proxyPasswordKey);
      deps.networkSync?.passwordChanged();
    default:
      break;
  }
}
