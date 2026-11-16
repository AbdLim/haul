import 'package:flutter_bloc/flutter_bloc.dart';

enum BrowserStatus {
  /// No browser extension has paired with the app yet.
  notPaired,

  /// An extension has paired and is reachable.
  connected,
}

/// Whether a browser extension is talking to Haul. The local bridge
/// drives it: it stays "not paired" until a browser proves its token.
class BrowserStatusCubit extends Cubit<BrowserStatus> {
  BrowserStatusCubit() : super(BrowserStatus.notPaired);

  void connected() => emit(BrowserStatus.connected);
  void notPaired() => emit(BrowserStatus.notPaired);
}
