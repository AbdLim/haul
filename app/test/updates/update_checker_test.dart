import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:haul/services/updates/update_checker.dart';

Map<String, Object?> release({
  String tag = 'v1.0.1',
  bool draft = false,
  bool prerelease = false,
  String body = '## Fixed\n- a thing',
  List<Map<String, Object?>>? assets,
}) => {
  'tag_name': tag,
  'draft': draft,
  'prerelease': prerelease,
  'body': body,
  'html_url': 'https://github.com/abdlim/haul/releases/tag/$tag',
  'published_at': '2026-12-01T10:00:00Z',
  'assets':
      assets ??
      [
        {
          'name': 'SHA256SUMS.txt',
          'browser_download_url':
              'https://github.com/abdlim/haul/releases/download/$tag/SHA256SUMS.txt',
          'size': 300,
        },
        {
          'name': 'Haul-1.0.1-unsigned.dmg',
          'browser_download_url':
              'https://github.com/abdlim/haul/releases/download/$tag/Haul-1.0.1-unsigned.dmg',
          'size': 25000000,
        },
      ],
};

GitHubUpdateChecker checker(Object? json, {String current = '1.0.0'}) =>
    GitHubUpdateChecker(
      repo: 'abdlim/haul',
      currentVersion: current,
      fetch: (_) async => jsonEncode(json),
    );

void main() {
  group('versions', () {
    test('compare numerically, not as text', () {
      int c(String a, String b) => GitHubUpdateChecker.compareVersions(a, b);
      expect(c('1.0.1', '1.0.0'), greaterThan(0));
      expect(c('1.0.0', '1.0.1'), lessThan(0));
      expect(c('1.0.0', '1.0.0'), 0);
      expect(c('1.10.0', '1.9.9'), greaterThan(0));
      expect(c('2.0.0', '1.99.99'), greaterThan(0));
      expect(c('1.0', '1.0.0'), 0);
      expect(c('1.0.1-beta', '1.0.0'), greaterThan(0));
    });
  });

  group('reading a release', () {
    test('a newer one gives its notes, page and DMG', () async {
      final info = (await checker(release()).checkForNewer())!;
      expect(info.version, '1.0.1');
      expect(info.notes, contains('a thing'));
      expect(
        info.pageUrl,
        'https://github.com/abdlim/haul/releases/tag/v1.0.1',
      );
      expect(info.fileName, 'Haul-1.0.1-unsigned.dmg');
      expect(info.size, 25000000);
      expect(info.downloadUrl, endsWith('Haul-1.0.1-unsigned.dmg'));
      expect(info.publishedAt, DateTime.utc(2026, 12, 1, 10));
    });

    test('the same or an older version is not an update', () async {
      expect(await checker(release(tag: 'v1.0.0')).checkForNewer(), isNull);
      expect(await checker(release(tag: 'v0.9.0')).checkForNewer(), isNull);
      expect(
        await checker(release(tag: 'v1.2.0'), current: '1.2.0').checkForNewer(),
        isNull,
      );
    });

    test('drafts and pre-releases are ignored', () async {
      expect(await checker(release(draft: true)).checkForNewer(), isNull);
      expect(await checker(release(prerelease: true)).checkForNewer(), isNull);
    });

    test('a release with no DMG still reports, without a download', () async {
      final info = (await checker(release(assets: [])).checkForNewer())!;
      expect(info.downloadUrl, isNull);
      expect(info.pageUrl, isNotEmpty);
    });

    test('a download link outside this repository is never used', () async {
      final info = (await checker(
        release(
          assets: [
            {
              'name': 'Haul.dmg',
              'browser_download_url': 'https://evil.example/Haul.dmg',
              'size': 1,
            },
            {
              'name': 'Haul.dmg',
              'browser_download_url': 'https://github.com/someone-else/haul/releases/download/v1/Haul.dmg',
              'size': 1,
            },
          ],
        ),
      ).checkForNewer())!;
      expect(info.downloadUrl, isNull);
    });

    test('a page link outside this repository is replaced', () async {
      final r = release()..['html_url'] = 'https://evil.example/x';
      final info = (await checker(r).checkForNewer())!;
      expect(info.pageUrl, startsWith('https://github.com/abdlim/haul/'));
    });

    test('rubbish from the server is a clear error, not a crash', () async {
      await expectLater(
        GitHubUpdateChecker(fetch: (_) async => 'not json').checkForNewer(),
        throwsA(isA<UpdateCheckException>()),
      );
      await expectLater(
        checker([1, 2]).checkForNewer(),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('it asks the right address', () async {
      Uri? asked;
      await GitHubUpdateChecker(
        repo: 'abdlim/haul',
        fetch: (u) async {
          asked = u;
          return jsonEncode(release(tag: 'v0.0.1'));
        },
      ).checkForNewer();
      expect(
        asked.toString(),
        'https://api.github.com/repos/abdlim/haul/releases/latest',
      );
    });
  });
}
