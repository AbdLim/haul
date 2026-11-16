import 'package:file_selector/file_selector.dart';

/// Asks the person to choose a folder.
abstract class FolderPicker {
  /// The chosen folder's path, or null if they cancelled.
  Future<String?> pick({String? startIn});
}

/// The system's own folder chooser.
///
/// Haul runs without the App Sandbox, so no entitlement is needed for it to
/// read or write wherever the person points.
class SystemFolderPicker implements FolderPicker {
  const SystemFolderPicker();

  @override
  Future<String?> pick({String? startIn}) =>
      getDirectoryPath(initialDirectory: startIn, confirmButtonText: 'Choose');
}
