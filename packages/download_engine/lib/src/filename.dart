import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _maxNameLength = 200;

/// Picks the file name for a download.
///
/// In order: the caller's [requested] name, `Content-Disposition`
/// (`filename*=UTF-8''...` beats `filename=`), the last segment of
/// [finalUrl], then `download`. The result is sanitized.
String resolveFileName({
  required Uri finalUrl,
  String? requested,
  String? contentDisposition,
}) {
  final candidates = <String?>[
    requested,
    _fromContentDisposition(contentDisposition),
    _fromUrl(finalUrl),
  ];
  for (final c in candidates) {
    if (c == null) continue;
    final clean = sanitizeFileName(c);
    if (clean.isNotEmpty) return clean;
  }
  return 'download';
}

String? _fromContentDisposition(String? header) {
  if (header == null) return null;
  final star = RegExp(
    r"filename\*\s*=\s*([^';]*)'[^';]*'([^;]+)",
    caseSensitive: false,
  ).firstMatch(header);
  if (star != null) {
    return _decode(star.group(2)!.trim(), charset: star.group(1));
  }
  final quoted = RegExp(
    r'filename\s*=\s*"((?:[^"\\]|\\.)*)"',
    caseSensitive: false,
  ).firstMatch(header);
  if (quoted != null) {
    return quoted
        .group(1)!
        .replaceAllMapped(RegExp(r'\\(["\\])'), (m) => m.group(1)!);
  }
  final bare = RegExp(
    r'filename\s*=\s*([^;]+)',
    caseSensitive: false,
  ).firstMatch(header);
  return bare?.group(1)?.trim();
}

String? _fromUrl(Uri url) {
  final segments = url.pathSegments;
  if (segments.isEmpty) return null;
  // Uri.pathSegments already percent-decodes.
  return segments.last;
}

/// Decodes RFC 5987 percent-encoding. [charset] is `UTF-8` or `ISO-8859-1`.
String _decode(String s, {String? charset}) {
  final bytes = <int>[];
  for (var i = 0; i < s.length; i++) {
    if (s[i] == '%' && i + 2 < s.length + 1 && i + 3 <= s.length) {
      final v = int.tryParse(s.substring(i + 1, i + 3), radix: 16);
      if (v != null) {
        bytes.add(v);
        i += 2;
        continue;
      }
    }
    bytes.addAll(utf8.encode(s[i]));
  }
  final latin1 = (charset ?? '').toLowerCase().contains('8859');
  return latin1
      ? String.fromCharCodes(bytes)
      : utf8.decode(bytes, allowMalformed: true);
}

/// Removes anything that could escape the folder or confuse the file
/// system, and trims the name to [_maxNameLength] characters while keeping
/// the extension.
String sanitizeFileName(String name) {
  // Only the last path component counts, whichever slash style was used.
  var base = name.split(RegExp(r'[/\\]')).last;
  base = base.replaceAll(RegExp(r'[\x00-\x1f\x7f:]'), '').trim();
  if (base == '.' || base == '..') return '';
  if (base.length <= _maxNameLength) return base;

  final dot = base.lastIndexOf('.');
  final hasExt = dot > 0 && base.length - dot <= 16;
  final ext = hasExt ? base.substring(dot) : '';
  final stem = hasExt ? base.substring(0, dot) : base;
  return stem.substring(0, min(stem.length, _maxNameLength - ext.length)) + ext;
}

/// Returns [name], or `name (1).ext`, `name (2).ext`, ... if the final file
/// or its `.part` file already exists in [dir].
String uniqueFileName(
  String dir,
  String name, {
  bool Function(String path)? exists,
}) {
  bool taken(String n) {
    final path = '$dir/$n';
    final check =
        exists ??
        (p) => FileSystemEntity.typeSync(p) != FileSystemEntityType.notFound;
    return check(path) || check('$path.part');
  }

  if (!taken(name)) return name;
  final dot = name.lastIndexOf('.');
  final hasExt = dot > 0;
  final stem = hasExt ? name.substring(0, dot) : name;
  final ext = hasExt ? name.substring(dot) : '';
  for (var i = 1; ; i++) {
    final candidate = '$stem ($i)$ext';
    if (!taken(candidate)) return candidate;
  }
}
