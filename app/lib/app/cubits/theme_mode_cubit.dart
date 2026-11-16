import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/setting_keys.dart';
import '../../data/settings_repository.dart';

/// The chosen appearance (system, dark or light), straight from settings.
class ThemeModeCubit extends Cubit<AppThemeMode> {
  ThemeModeCubit(SettingsRepository settings)
    : super(settings.get(Keys.themeMode)) {
    _sub = settings.watch(Keys.themeMode).listen(emit);
  }

  late final StreamSubscription<AppThemeMode> _sub;

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
