import 'dart:io';

import '../add_download/add_download_cubit.dart';

/// Finds a web link in something that was dropped on the window.
///
/// Dragging a link out of a browser's address bar gives plain text; saving
/// one to the desktop gives a `.webloc` (macOS) or `.url` (Windows style)
/// shortcut file; people also drop a text file with the link in it. All of
/// them end up as an `http` or `https` [Uri], or null if there is no link.
abstract final class LinkExtractor {
  /// A shortcut or text file bigger than this is not read: it is not a link.
  static const maxFileBytes = 64 * 1024;

  /// The first web link in free text, such as a dropped string.
  static Uri? fromText(String text) {
    for (final token in text.split(RegExp(r'\s+'))) {
      final uri = AddDownloadCubit.parseLink(token);
      if (uri != null) return uri;
    }
    return null;
  }

  /// The link in a macOS `.webloc` file, which is an XML property list with a
  /// `URL` key.
  static Uri? fromWebloc(String xml) {
    final m = RegExp(
      r'<key>\s*URL\s*</key>\s*<string>\s*([^<]+?)\s*</string>',
      caseSensitive: false,
    ).firstMatch(xml);
    if (m == null) return null;
    return AddDownloadCubit.parseLink(_unescape(m.group(1)!));
  }

  /// The link in an internet shortcut (`.url`) file: an INI file with
  /// `URL=` in it.
  static Uri? fromUrlFile(String ini) {
    final m = RegExp(
      r'^\s*URL\s*=\s*(\S+)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(ini);
    return m == null ? null : AddDownloadCubit.parseLink(m.group(1)!);
  }

  /// The link in the file at [path], judged by its extension. Anything that
  /// is not a small link file gives null.
  static Future<Uri?> fromFile(String path) async {
    final file = File(path);
    try {
      if (!file.existsSync() || await file.length() > maxFileBytes) return null;
      final text = await file.readAsString();
      final lower = path.toLowerCase();
      if (lower.endsWith('.webloc')) return fromWebloc(text);
      if (lower.endsWith('.url')) return fromUrlFile(text);
      if (lower.endsWith('.txt') || lower.endsWith('.md')) {
        return fromText(text);
      }
      return null;
    } on FileSystemException {
      return null;
    } on FormatException {
      // Not text at all.
      return null;
    }
  }

  /// The first link found in any of [paths].
  static Future<Uri?> fromFiles(Iterable<String> paths) async {
    for (final p in paths) {
      final uri = await fromFile(p);
      if (uri != null) return uri;
    }
    return null;
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}
