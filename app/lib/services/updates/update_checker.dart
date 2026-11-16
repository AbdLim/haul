import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../app/version.dart';

/// A published Haul release that is newer than the running one.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    this.downloadUrl,
    this.fileName,
    this.size,
    this.publishedAt,
  });

  /// `1.0.1`, without the `v`.
  final String version;

  /// The release notes, as Markdown: our changelog section, then GitHub's list
  /// of changes and contributors.
  final String notes;

  /// The release's page on GitHub.
  final String pageUrl;

  /// The DMG, if the release has one.
  final String? downloadUrl;
  final String? fileName;
  final int? size;
  final DateTime? publishedAt;
}

/// A check that could not be completed, with words fit to show.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Finds out whether a newer Haul exists.
abstract class UpdateSource {
  /// The newest release if it is newer than this one, or null if Haul is up to
  /// date. Throws [UpdateCheckException] when GitHub cannot be reached or
  /// answers with something unusable.
  Future<UpdateInfo?> checkForNewer();
}

/// Reads `https://api.github.com/repos/<repo>/releases/latest`. Nothing but the
/// request itself is sent: no identifier, no version, no account.
class GitHubUpdateChecker implements UpdateSource {
  GitHubUpdateChecker({
    this.repo = updateRepo,
    this.currentVersion = appVersion,
    Future<String> Function(Uri url)? fetch,
  }) : _fetch = fetch ?? _get;

  final String repo;
  final String currentVersion;
  final Future<String> Function(Uri url) _fetch;

  static Future<String> _get(Uri url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'Haul';
    try {
      final request = await client.getUrl(url);
      request.headers
        ..set('Accept', 'application/vnd.github+json')
        ..set('X-GitHub-Api-Version', '2022-11-28');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 404) {
        // No public release yet (or the repository is private).
        throw const UpdateCheckException('No release has been published yet.');
      }
      if (response.statusCode != 200) {
        throw UpdateCheckException(
          'GitHub answered with an error (${response.statusCode}).',
        );
      }
      return await utf8
          .decodeStream(response)
          .timeout(const Duration(seconds: 15));
    } on SocketException {
      throw const UpdateCheckException('Could not reach GitHub.');
    } on TimeoutException {
      throw const UpdateCheckException('GitHub took too long to answer.');
    } on HandshakeException {
      throw const UpdateCheckException('Could not make a secure connection.');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<UpdateInfo?> checkForNewer() async {
    final body = await _fetch(
      Uri.https('api.github.com', '/repos/$repo/releases/latest'),
    );
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw const UpdateCheckException('GitHub sent something unexpected.');
    }
    return parseRelease(json);
  }

  /// Turns GitHub's release JSON into an [UpdateInfo], or null if it is not
  /// newer. Public so tests can feed it real-shaped data.
  UpdateInfo? parseRelease(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const UpdateCheckException('GitHub sent something unexpected.');
    }
    final tag = json['tag_name'];
    if (tag is! String || json['draft'] == true || json['prerelease'] == true) {
      return null;
    }
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (compareVersions(version, currentVersion) <= 0) return null;

    final page = 'https://github.com/$repo/';
    final htmlUrl = json['html_url'];
    final pageUrl = htmlUrl is String && htmlUrl.startsWith(page)
        ? htmlUrl
        : '${page}releases/tag/$tag';

    // Only the DMG, and only from this repository's own release downloads: what
    // the API says is never trusted to point anywhere else.
    String? downloadUrl;
    String? fileName;
    int? size;
    final assets = json['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is! Map<String, Object?>) continue;
        final name = a['name'];
        final url = a['browser_download_url'];
        if (name is String &&
            name.endsWith('.dmg') &&
            url is String &&
            url.startsWith('${page}releases/download/')) {
          downloadUrl = url;
          fileName = name;
          size = a['size'] is int ? a['size'] as int : null;
          break;
        }
      }
    }
    final published = json['published_at'];
    return UpdateInfo(
      version: version,
      notes: json['body'] is String ? json['body'] as String : '',
      pageUrl: pageUrl,
      downloadUrl: downloadUrl,
      fileName: fileName,
      size: size,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
    );
  }

  /// Negative, zero or positive as [a] is older than, equal to or newer than
  /// [b]. Compares `major.minor.patch` numerically; anything after a `-` or `+`
  /// is ignored.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => [
      for (final p in v.split(RegExp(r'[-+]')).first.split('.'))
        int.tryParse(p) ?? 0,
    ];
    final x = parts(a);
    final y = parts(b);
    for (var i = 0; i < 3; i++) {
      final l = i < x.length ? x[i] : 0;
      final r = i < y.length ? y[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }
}
