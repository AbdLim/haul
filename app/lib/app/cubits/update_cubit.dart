import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/setting_keys.dart';
import '../../data/settings_repository.dart';
import '../../services/updates/update_checker.dart';

enum UpdateStatus { idle, checking, upToDate, available, failed }

class UpdateState extends Equatable {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.info,
    this.error,
    this.bannerHidden = false,
  });

  final UpdateStatus status;

  /// The newer release, when [status] is `available`.
  final UpdateInfo? info;
  final String? error;

  /// "Later": the banner is gone until the next launch.
  final bool bannerHidden;

  @override
  List<Object?> get props => [status, info?.version, error, bannerHidden];
}

/// Looks for a newer Haul: once a day while the app runs (if the person has not
/// switched it off), and on demand from Settings, About.
class UpdateCubit extends Cubit<UpdateState> {
  UpdateCubit({
    required UpdateSource source,
    required SettingsRepository settings,
    DateTime Function()? clock,
  }) : _source = source,
       _settings = settings,
       _clock = clock ?? DateTime.now,
       super(const UpdateState());

  final UpdateSource _source;
  final SettingsRepository _settings;
  final DateTime Function() _clock;

  /// A day between automatic checks.
  static const interval = Duration(hours: 24);

  Timer? _timer;

  /// Starts the automatic checks: now if one is due, then every few hours
  /// (which only runs a check when a day has passed).
  void startAutomatic({Duration every = const Duration(hours: 6)}) {
    unawaited(checkIfDue());
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => unawaited(checkIfDue()));
  }

  bool get _due {
    final last = _settings.get(Keys.lastUpdateCheck);
    if (last == null) return true;
    final at = DateTime.fromMillisecondsSinceEpoch(last * 1000);
    return _clock().difference(at) >= interval;
  }

  /// A check that respects the setting and the once-a-day limit. Failures are
  /// silent: nobody needs to hear that GitHub was unreachable.
  Future<void> checkIfDue() async {
    if (!_settings.get(Keys.checkForUpdates) || !_due) return;
    await _run(silent: true);
  }

  /// A check the person asked for. Always runs and always reports.
  Future<void> checkNow() => _run(silent: false);

  Future<void> _run({required bool silent}) async {
    if (state.status == UpdateStatus.checking || isClosed) return;
    final before = state;
    emit(
      UpdateState(
        status: UpdateStatus.checking,
        bannerHidden: state.bannerHidden,
      ),
    );
    try {
      final info = await _source.checkForNewer();
      await _settings.set(
        Keys.lastUpdateCheck,
        _clock().millisecondsSinceEpoch ~/ 1000,
      );
      if (isClosed) return;
      emit(
        info == null
            ? UpdateState(
                status: UpdateStatus.upToDate,
                bannerHidden: before.bannerHidden,
              )
            : UpdateState(
                status: UpdateStatus.available,
                info: info,
                bannerHidden: before.bannerHidden,
              ),
      );
    } on UpdateCheckException catch (e) {
      if (isClosed) return;
      emit(
        silent
            ? before
            : UpdateState(
                status: UpdateStatus.failed,
                error: e.message,
                bannerHidden: before.bannerHidden,
              ),
      );
    }
  }

  /// Whether the banner should show: a newer version, not skipped, not put
  /// off for now.
  bool get showBanner {
    final info = state.info;
    return state.status == UpdateStatus.available &&
        info != null &&
        !state.bannerHidden &&
        _settings.get(Keys.skippedUpdate) != info.version;
  }

  /// "Later": hide the banner until the app is opened again.
  void later() => emit(
    UpdateState(status: state.status, info: state.info, bannerHidden: true),
  );

  /// "Skip this version": its banner never comes back (a newer one will).
  Future<void> skip() async {
    final info = state.info;
    if (info == null) return;
    await _settings.set(Keys.skippedUpdate, info.version);
    if (!isClosed) later();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
