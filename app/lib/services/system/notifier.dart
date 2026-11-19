import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

/// Banners in the corner of the screen.
abstract class Notifier {
  /// Shows a banner. [onClick] runs if the person clicks it.
  Future<void> show({
    required String title,
    required String body,
    VoidCallback? onClick,
  });

  static Notifier get current {
    if (Platform.isMacOS || Platform.isWindows) return LocalNotifierService();
    throw UnsupportedError('No notifications for ${Platform.operatingSystem}');
  }
}

class LocalNotifierService implements Notifier {
  bool _ready = false;

  // A banner must be kept alive until it is gone, or its click is lost.
  final _live = <LocalNotification>{};

  @override
  Future<void> show({
    required String title,
    required String body,
    VoidCallback? onClick,
  }) async {
    try {
      if (!_ready) {
        await localNotifier.setup(appName: 'Haul');
        _ready = true;
      }
      late final LocalNotification n;
      n = LocalNotification(title: title, body: body)
        ..onClick = () {
          _live.remove(n);
          onClick?.call();
        }
        ..onClose = (_) => _live.remove(n);
      _live.add(n);
      await n.show();
    } on Object catch (e) {
      // A banner that cannot be shown must never break a download.
      debugPrint('Notification failed: $e');
    }
  }
}

/// For tests: records what would have been shown.
class FakeNotifier implements Notifier {
  final shown = <({String title, String body, VoidCallback? onClick})>[];

  @override
  Future<void> show({
    required String title,
    required String body,
    VoidCallback? onClick,
  }) async => shown.add((title: title, body: body, onClick: onClick));
}
