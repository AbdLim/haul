import '../../services/bridge/bridge_payload.dart';

/// A download the browser extension sent, waiting for the person to confirm
/// it in the Add dialog.
class BrowserHandoff {
  const BrowserHandoff({required this.id, required this.payload});

  /// The id already given to the extension in the bridge's answer.
  final String id;
  final BridgePayload payload;

  /// "Chrome", "Firefox": the browser's name for people.
  String get browserName {
    final s = payload.source;
    return s.isEmpty ? 'your browser' : s[0].toUpperCase() + s.substring(1);
  }
}
