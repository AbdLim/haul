import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/setting_keys.dart';
import '../features/add_download/add_download_host.dart';
import '../features/debug/component_gallery.dart';
import '../features/detail/detail_panel.dart';
import '../features/downloads/downloads_list.dart';
import '../features/drop/link_drop_target.dart';
import '../features/header/header_band.dart';
import '../features/settings/settings_view.dart';
import '../features/shell/shell_page.dart';
import '../features/sidebar/sidebar.dart';
import '../features/add_download/browser_handoff.dart';
import '../services/bridge/browser_intake.dart';
import 'commands.dart';
import 'cubits/browser_status_cubit.dart';
import 'cubits/downloads_cubit.dart';
import 'cubits/setting_cubit.dart';
import 'cubits/shell_cubit.dart';
import 'cubits/theme_mode_cubit.dart';
import 'cubits/throughput_cubit.dart';
import 'dependencies.dart';
import 'integration/system_integration.dart';
import 'menu_bar.dart';
import 'scroll_behavior.dart';
import 'theme/haul_theme.dart';

/// The root of the app. Built on the widgets layer, not Material: every pixel
/// is drawn by Haul's own components and theme.
class HaulApp extends StatefulWidget {
  const HaulApp({required this.deps, this.native = true, super.key});

  final AppDependencies deps;

  /// False in tests, where there is no native window to talk to.
  final bool native;

  @override
  State<HaulApp> createState() => _HaulAppState();
}

class _HaulAppState extends State<HaulApp> {
  late final ShellCubit _shell = ShellCubit();
  late final DownloadsCubit _downloads = DownloadsCubit(
    widget.deps.downloads,
    widget.deps.categories,
  );
  late final LiveCubit _live = LiveCubit(widget.deps.downloads);
  late final ThemeModeCubit _themeMode = ThemeModeCubit(widget.deps.settings);
  late final SettingCubit<ListDensity> _density = SettingCubit(
    widget.deps.settings,
    Keys.listDensity,
  );
  late final BrowserStatusCubit _browser = BrowserStatusCubit();
  late final ThroughputCubit _throughput = ThroughputCubit(
    live: _live,
    downloads: _downloads,
  );
  final _navigator = GlobalKey<NavigatorState>();
  late final HaulCommands _commands = HaulCommands(
    shell: _shell,
    downloads: _downloads,
  )..openGallery = kDebugMode ? _openGallery : null;

  SystemIntegration? _system;
  Timer? _browserTimer;

  /// The browser said hello with the right token. It polls every minute, so
  /// a few minutes of silence means it has gone.
  void _browserSeen() {
    _browser.connected();
    _browserTimer?.cancel();
    _browserTimer = Timer(const Duration(minutes: 3), _browser.notPaired);
  }

  @override
  void initState() {
    super.initState();
    widget.deps.bridge?.onAuthenticated = _browserSeen;
    _wireIntake();
    if (widget.native) {
      _system = SystemIntegration(
        deps: widget.deps,
        downloads: _downloads,
        throughput: _throughput,
        commands: _commands,
        navigator: _navigator,
      );
    }
  }

  /// A download from the browser: with "start at once" off it opens the Add
  /// dialog filled in; with it on (or the dialog already busy) it just joins
  /// the queue and a banner says so.
  void _wireIntake() {
    final intake = widget.deps.intake;
    if (intake == null) return;
    intake.onAsk = (id, payload) async {
      if (_shell.state.addDialogOpen) {
        await intake.add(id, payload);
        intake.onAdded?.call(BrowserIntake.nameFor(payload));
        return;
      }
      await widget.deps.window?.show();
      _shell.openAddDialog(
        handoff: BrowserHandoff(id: id, payload: payload),
      );
    };
    intake.onAdded = (name) => _system?.alerts?.announceQueued(name);
  }

  void _openGallery() {
    _navigator.currentState?.push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => const ComponentGallery(),
        transitionDuration: const Duration(milliseconds: 120),
        transitionsBuilder: (context, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    widget.deps.bridge?.onAuthenticated = null;
    widget.deps.intake?.onAsk = null;
    widget.deps.intake?.onAdded = null;
    _browserTimer?.cancel();
    _system?.dispose();
    _shell.close();
    _downloads.close();
    _live.close();
    _themeMode.close();
    _density.close();
    _browser.close();
    _throughput.close();
    super.dispose();
  }

  static PageRoute<T> _fade<T>(RouteSettings settings, WidgetBuilder builder) =>
      PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AppDependencies>.value(
      value: widget.deps,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _shell),
          BlocProvider.value(value: _downloads),
          BlocProvider.value(value: _live),
          BlocProvider.value(value: _themeMode),
          BlocProvider.value(value: _density),
          BlocProvider.value(value: _browser),
          BlocProvider.value(value: _throughput),
        ],
        child: WidgetsApp(
          title: 'Haul',
          navigatorKey: _navigator,
          color: HaulTheme.dark.colors.bgWindow,
          debugShowCheckedModeBanner: false,
          pageRouteBuilder: _fade,
          // The theme sits above the Navigator, so menus and dialogs, which are
          // routes of their own, see it too.
          builder: (context, navigator) =>
              BlocBuilder<ThemeModeCubit, AppThemeMode>(
                builder: (context, mode) => HaulThemeScope(
                  mode: mode,
                  child: ScrollConfiguration(
                    behavior: const HaulScrollBehavior(),
                    child: _BrightnessSync(
                      deps: widget.deps,
                      child: navigator!,
                    ),
                  ),
                ),
              ),
          home: HaulMenuBar(
            commands: _commands,
            child: AddDownloadHost(
              deps: widget.deps,
              readClipboard: widget.native,
              child: LinkDropTarget(
                native: widget.native,
                child: ShellPage(
                  chrome: widget.deps.chrome,
                  native: widget.native,
                  sidebar: const Sidebar(),
                  header: const HeaderBand(),
                  content: const DownloadsList(),
                  detail: const DetailPanelHost(),
                  settings: SettingsView(native: widget.native),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps native effects, like the sidebar blur, in the same appearance as
/// the app.
class _BrightnessSync extends StatefulWidget {
  const _BrightnessSync({required this.deps, required this.child});

  final AppDependencies deps;
  final Widget child;

  @override
  State<_BrightnessSync> createState() => _BrightnessSyncState();
}

class _BrightnessSyncState extends State<_BrightnessSync> {
  Brightness? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final b = HaulTheme.of(context).brightness;
    if (b != _last) {
      _last = b;
      widget.deps.chrome.applyBrightness(b);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
