import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/system/app_window.dart';
import '../components/components.dart';
import '../cubits/downloads_cubit.dart';

/// Quitting while downloads are running asks first. Quitting with nothing
/// running just quits.
class QuitGuard {
  QuitGuard({
    required this.window,
    required this.downloads,
    required this.navigator,
    this.beforeQuit,
  }) {
    _sub = window.quitRequests.listen((_) => requestQuit());
  }

  final AppWindow window;
  final StateStreamable<DownloadsState> downloads;
  final GlobalKey<NavigatorState> navigator;

  /// Runs just before quitting, to save progress.
  final Future<void> Function()? beforeQuit;
  late final StreamSubscription<void> _sub;
  bool _asking = false;

  int get _running => downloads.state.downloads
      .where(
        (d) =>
            d.snapshot.status.isActive ||
            d.snapshot.status == DownloadStatus.queued,
      )
      .length;

  /// Called for every way of quitting (shortcut, Dock, menu bar icon).
  Future<void> requestQuit() async {
    if (_asking) return;
    final n = _running;
    final context = navigator.currentContext;
    if (n == 0 || context == null) return _quit();
    _asking = true;
    // The question belongs in front of the window.
    await window.show();
    if (!context.mounted) return _quit();
    final quit = await confirm(
      context,
      title: 'Quit Haul?',
      message: n == 1
          ? 'A download is still running. It will pause and carry on when '
                'you open Haul again.'
          : '$n downloads are still running. They will pause and carry on '
                'when you open Haul again.',
      confirmLabel: 'Quit',
      cancelLabel: 'Keep downloading',
    );
    _asking = false;
    if (quit) await _quit();
  }

  Future<void> _quit() async {
    await beforeQuit?.call();
    await window.quit();
  }

  Future<void> dispose() => _sub.cancel();
}
