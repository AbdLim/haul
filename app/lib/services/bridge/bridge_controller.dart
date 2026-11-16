import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/version.dart';
import '../../data/setting_keys.dart';
import '../../data/settings_repository.dart';
import 'bridge_server.dart';

class BridgeState extends Equatable {
  const BridgeState({this.port, this.error});

  /// The port in use, or null when the bridge is off or failed to start.
  final int? port;

  /// Why it could not start, in words, for the Settings screen.
  final String? error;

  bool get listening => port != null;

  @override
  List<Object?> get props => [port, error];
}

/// Keeps the bridge server running as the settings say: started with the app
/// when browser integration is on, and restarted when the port changes. A port
/// that is taken is reported, never fatal.
class BridgeController extends Cubit<BridgeState> {
  BridgeController({
    required SettingsRepository settings,
    required this.backend,
    this.onAuthenticated,
    this.portOverride,
  }) : _settings = settings,
       super(const BridgeState());

  final SettingsRepository _settings;
  final BridgeBackend backend;
  void Function()? onAuthenticated;

  /// For tests: listen here instead of on the port setting (0 = any free).
  final int? portOverride;

  BridgeServer? _server;
  final _subs = <StreamSubscription<Object?>>[];
  Future<void> _chain = Future.value();

  Future<void> start() async {
    for (final key in [Keys.browserIntegrationEnabled, Keys.bridgePort]) {
      _subs.add(_settings.watch(key).skip(1).listen((_) => _apply()));
    }
    await _apply();
  }

  /// Runs one apply at a time, so quick changes cannot start two servers.
  Future<void> _apply() => _chain = _chain.then((_) => _applyNow());

  Future<void> _applyNow() async {
    if (isClosed) return;
    await _server?.close();
    _server = null;
    if (!_settings.get(Keys.browserIntegrationEnabled)) {
      return emit(const BridgeState());
    }
    final port = portOverride ?? _settings.get<int>(Keys.bridgePort);
    try {
      _server = await BridgeServer.start(
        port: port,
        token: () => _settings.get(Keys.bridgeToken),
        backend: backend,
        version: appVersion,
        onAuthenticated: () => onAuthenticated?.call(),
      );
      emit(BridgeState(port: _server!.port));
    } on SocketException {
      emit(
        BridgeState(
          error: 'Port $port is in use by another app. Choose another port.',
        ),
      );
    } on Object {
      emit(
        BridgeState(error: 'The browser link could not start on port $port.'),
      );
    }
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _chain;
    await _server?.close();
    _server = null;
    return super.close();
  }
}
