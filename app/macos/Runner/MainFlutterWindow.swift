import Cocoa
import FlutterMacOS
import macos_window_utils

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // macos_window_utils needs its own view controller (required for macOS
    // 12 and earlier, which is Haul's minimum).
    let windowFrame = self.frame
    let macOSWindowUtilsViewController = MacOSWindowUtilsViewController()
    self.contentViewController = macOSWindowUtilsViewController
    self.setFrame(windowFrame, display: true)

    MainFlutterWindowManipulator.start(mainFlutterWindow: self)

    RegisterGeneratedPlugins(registry: macOSWindowUtilsViewController.flutterViewController)

    HaulWindowBridge.shared.attach(
      window: self,
      messenger: macOSWindowUtilsViewController.flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  /// The red button and Command-W hide the window instead of closing it, so
  /// downloads carry on and the window can come back with its state intact.
  override func close() {
    orderOut(nil)
  }
}
