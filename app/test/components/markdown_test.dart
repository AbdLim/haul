import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';

import '../support/widget_host.dart';

void main() {
  group('blocks', () {
    test('headings, paragraphs joined across lines, and lists', () {
      final b = parseMarkdown('''
# Title

One line
and the next.

## Sub
- first
  continued here
- second
1. one
2. two
''');
      expect(b[0], isA<MdHeading>().having((h) => h.level, 'level', 1));
      expect((b[1] as MdParagraph).text, 'One line and the next.');
      expect((b[2] as MdHeading).text, 'Sub');
      expect((b[3] as MdListItem).text, 'first continued here');
      expect((b[3] as MdListItem).marker, '•');
      expect((b[5] as MdListItem).marker, '1.');
      expect(b, hasLength(7));
    });

    test('fenced code keeps its lines and ignores markdown inside', () {
      final b = parseMarkdown('```\n# not a heading\n- not a list\n```\nafter');
      expect((b[0] as MdCode).text, '# not a heading\n- not a list');
      expect((b[1] as MdParagraph).text, 'after');
    });

    test('a table has a header and rows', () {
      final b = parseMarkdown('''
| Pane | What |
| --- | --- |
| General | Login |
| Proxy | **None** |
''');
      final t = b.single as MdTable;
      expect(t.header, ['Pane', 'What']);
      expect(t.rows, [
        ['General', 'Login'],
        ['Proxy', '**None**'],
      ]);
    });
  });

  group('inline', () {
    test('bold, italic, code and links', () {
      final s = parseInline('a **b** `c` *d* [e](http://x) f');
      expect(s.map((x) => x.text), [
        'a ',
        'b',
        ' ',
        'c',
        ' ',
        'd',
        ' ',
        'e',
        ' f',
      ]);
      expect(s[1].bold, isTrue);
      expect(s[3].code, isTrue);
      expect(s[5].italic, isTrue);
      expect(s[7].link, 'http://x');
    });

    test('bold around code keeps both', () {
      final s = parseInline('**`x`**');
      expect(s.single.bold && s.single.code, isTrue);
    });

    test('a lone star or an underscore in a word is left alone', () {
      expect(
        parseInline('2 * 3 and snake_case').single.text,
        '2 * 3 and snake_case',
      );
    });
  });

  testWidgets('the real guide and README render with no markup showing', (
    tester,
  ) async {
    final source = File('../README.md').readAsStringSync();
    await pumpHaul(
      tester,
      SingleChildScrollView(child: HaulMarkdown(source)),
      size: const Size(900, 700),
    );
    final shown = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .join('\n');
    expect(shown, contains('Add a download'));
    expect(shown, contains('Troubleshooting'));
    // Markup characters must not leak through.
    expect(shown, isNot(contains('**')));
    expect(shown, isNot(contains('## ')));
    expect(shown, isNot(contains('](http')));
    expect(shown, isNot(contains('| ---')));
    expect(shown, isNot(contains('```')));
    expect(tester.takeException(), isNull);
  });
}
