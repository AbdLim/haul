import Cocoa
import FlutterMacOS

/// The few window things Flutter cannot do from Dart: hiding instead of
/// closing, bringing the window back, and asking before quitting.
final class HaulWindowBridge {
  static let shared = HaulWindowBridge()

  weak var window: NSWindow?
  private var channel: FlutterMethodChannel?
  var quitApproved = false
  /// True when the previous run left a saved window frame that was restored.
  private(set) var restoredFrame = false

  func attach(window: NSWindow, messenger: FlutterBinaryMessenger) {
    self.window = window
    // AppKit remembers the size and position under this name.
    window.setFrameAutosaveName("HaulMainWindow")
    restoredFrame = window.setFrameUsingName("HaulMainWindow")

    let channel = FlutterMethodChannel(
      name: "dev.haul.app/window", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "show":
        self?.showWindow()
        result(nil)
      case "hide":
        self?.window?.orderOut(nil)
        result(nil)
      case "isVisible":
        result(self?.window?.isVisible ?? false)
      case "hasSavedFrame":
        result(self?.restoredFrame ?? false)
      case "startedHidden":
        // launchd names the job it starts in XPC_SERVICE_NAME; the login item
        // Haul writes uses the app's bundle id as its label.
        let info = ProcessInfo.processInfo
        result(
          info.arguments.contains("--hidden")
            || info.environment["XPC_SERVICE_NAME"] == "dev.haul.app")
      case "quit":
        self?.quitApproved = true
        NSApp.terminate(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  func showWindow() {
    guard let window = window else { return }
    NSApp.activate(ignoringOtherApps: true)
    if window.isMiniaturized { window.deminiaturize(nil) }
    window.makeKeyAndOrderFront(nil)
  }

  /// Returns true when Dart has been asked (and will call `quit`).
  func askDartToQuit() -> Bool {
    guard let channel = channel else { return false }
    channel.invokeMethod("quitRequested", arguments: nil)
    return true
  }
}
