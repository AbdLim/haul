import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

void main() {
  group('resolveFileName', () {
    final cases =
        <
          ({
            String label,
            String url,
            String? cd,
            String? requested,
            String expect,
          })
        >[
          (
            label: 'quoted filename',
            url: 'https://e.com/x',
            cd: 'attachment; filename="report.pdf"',
            requested: null,
            expect: 'report.pdf',
          ),
          (
            label: 'unquoted filename',
            url: 'https://e.com/x',
            cd: 'attachment; filename=report.pdf',
            requested: null,
            expect: 'report.pdf',
          ),
          (
            label: 'quoted name with spaces',
            url: 'https://e.com/x',
            cd: 'attachment; filename="my report.pdf"',
            requested: null,
            expect: 'my report.pdf',
          ),
          (
            label: 'filename* UTF-8',
            url: 'https://e.com/x',
            cd: "attachment; filename*=UTF-8''r%C3%A9sum%C3%A9.pdf",
            requested: null,
            expect: 'résumé.pdf',
          ),
          (
            label: 'filename* beats filename',
            url: 'https://e.com/x',
            cd: "attachment; filename=\"plain.bin\"; filename*=UTF-8''fancy%20name.bin",
            requested: null,
            expect: 'fancy name.bin',
          ),
          (
            label: 'filename* ISO-8859-1',
            url: 'https://e.com/x',
            cd: "attachment; filename*=ISO-8859-1''caf%E9.txt",
            requested: null,
            expect: 'café.txt',
          ),
          (
            label: 'URL path, percent-decoded',
            url: 'https://e.com/files/archive%20v2.zip',
            cd: null,
            requested: null,
            expect: 'archive v2.zip',
          ),
          (
            label: 'URL with a query string',
            url: 'https://e.com/dl/file.iso?token=abc&x=1',
            cd: null,
            requested: null,
            expect: 'file.iso',
          ),
          (
            label: 'URL ending in a slash',
            url: 'https://e.com/downloads/',
            cd: null,
            requested: null,
            expect: 'download',
          ),
          (
            label: 'URL with no path',
            url: 'https://e.com',
            cd: null,
            requested: null,
            expect: 'download',
          ),
          (
            label: 'caller name wins',
            url: 'https://e.com/a.zip',
            cd: 'attachment; filename="b.zip"',
            requested: 'mine.zip',
            expect: 'mine.zip',
          ),
          (
            label: 'empty Content-Disposition falls through to URL',
            url: 'https://e.com/a.zip',
            cd: 'attachment',
            requested: null,
            expect: 'a.zip',
          ),
          (
            label: 'path traversal',
            url: 'https://e.com/x',
            cd: 'attachment; filename="../../etc/passwd"',
            requested: null,
            expect: 'passwd',
          ),
          (
            label: 'backslash traversal',
            url: 'https://e.com/x',
            cd: r'attachment; filename="..\..\evil.exe"',
            requested: null,
            expect: 'evil.exe',
          ),
          (
            label: 'colon and control characters',
            url: 'https://e.com/x',
            cd: 'attachment; filename="a:b\u0001c.txt"',
            requested: null,
            expect: 'abc.txt',
          ),
          (
            label: 'only dots',
            url: 'https://e.com/x',
            cd: 'attachment; filename=".."',
            requested: null,
            expect: 'x',
          ),
          (
            label: 'encoded slash in URL',
            url: 'https://e.com/a%2Fb.zip',
            cd: null,
            requested: null,
            expect: 'b.zip',
          ),
        ];
    for (final c in cases) {
      test(c.label, () {
        expect(
          resolveFileName(
            finalUrl: Uri.parse(c.url),
            contentDisposition: c.cd,
            requested: c.requested,
          ),
          c.expect,
        );
      });
    }
  });

  group('sanitizeFileName', () {
    test('trims to 200 characters and keeps the extension', () {
      final long = '${'a' * 300}.tar.gz';
      final out = sanitizeFileName(long);
      expect(out.length, 200);
      expect(out.endsWith('.gz'), isTrue);
    });

    test('short names are untouched', () {
      expect(sanitizeFileName('ok.txt'), 'ok.txt');
    });
  });

  group('uniqueFileName', () {
    test('returns the name when free', () {
      expect(uniqueFileName('/d', 'a.zip', exists: (_) => false), 'a.zip');
    });

    test('two collisions in a row', () {
      final taken = {'/d/a.zip', '/d/a (1).zip'};
      expect(
        uniqueFileName('/d', 'a.zip', exists: taken.contains),
        'a (2).zip',
      );
    });

    test('a .part file counts as a collision', () {
      final taken = {'/d/a.zip.part'};
      expect(
        uniqueFileName('/d', 'a.zip', exists: taken.contains),
        'a (1).zip',
      );
    });

    test('names without an extension', () {
      final taken = {'/d/README'};
      expect(
        uniqueFileName('/d', 'README', exists: taken.contains),
        'README (1)',
      );
    });
  });
}
