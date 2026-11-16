import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/setting_key.dart';
import '../../data/settings_repository.dart';

/// Follows one setting: its value now and every change, for any widget that
/// needs to look different when it changes.
class SettingCubit<T> extends Cubit<T> {
  SettingCubit(SettingsRepository settings, SettingKey<T> key)
    : super(settings.get(key)) {
    _sub = settings.watch(key).listen(emit);
  }

  late final StreamSubscription<T> _sub;

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
