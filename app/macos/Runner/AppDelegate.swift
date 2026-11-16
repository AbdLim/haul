import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Closing the window only hides it; downloads keep running and the Dock
  /// icon and menu bar icon bring it back.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Clicking the Dock icon while the window is hidden shows it again.
  override func applicationShouldHandleReopen(
    _ sender: NSApplication, hasVisibleWindows flag: Bool
  ) -> Bool {
    HaulWindowBridge.shared.showWindow()
    return false
  }

  /// Command-Q and "Quit" in the Dock menu ask Dart first, so it can warn
  /// about downloads in progress. Dart answers by calling `quit`.
  override func applicationShouldTerminate(_ sender: NSApplication)
    -> NSApplication.TerminateReply
  {
    if HaulWindowBridge.shared.quitApproved { return .terminateNow }
    if HaulWindowBridge.shared.askDartToQuit() { return .terminateCancel }
    return .terminateNow
  }
}
