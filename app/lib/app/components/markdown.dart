import 'package:flutter/widgets.dart';

import '../theme/haul_theme.dart';

/// The small part of Markdown Haul's own README uses: headings, paragraphs,
/// bullet and numbered lists, fenced code, tables, and inline bold, italic,
/// code and links. Drawn with Haul's own text styles; nothing from Material.
sealed class MdBlock {
  const MdBlock();
}

class MdHeading extends MdBlock {
  const MdHeading(this.level, this.text);
  final int level;
  final String text;
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.text);
  final String text;
}

class MdListItem extends MdBlock {
  const MdListItem(this.marker, this.depth, this.text);

  /// `•` or `1.`
  final String marker;
  final int depth;
  final String text;
}

class MdCode extends MdBlock {
  const MdCode(this.text);
  final String text;
}

class MdTable extends MdBlock {
  const MdTable(this.header, this.rows);
  final List<String> header;
  final List<List<String>> rows;
}

final _fence = RegExp(r'^\s*```');
final _heading = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$');
final _item = RegExp(r'^(\s*)([-*+]|\d+\.)\s+(.*)$');
final _tableRule = RegExp(r'^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$');

List<String> _cells(String line) {
  var t = line.trim();
  if (t.startsWith('|')) t = t.substring(1);
  if (t.endsWith('|')) t = t.substring(0, t.length - 1);
  return [for (final c in t.split('|')) c.trim()];
}

/// Splits [source] into blocks.
List<MdBlock> parseMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final out = <MdBlock>[];
  final para = <String>[];

  void flush() {
    if (para.isNotEmpty) out.add(MdParagraph(para.join(' ')));
    para.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];

    if (_fence.hasMatch(line)) {
      flush();
      final code = <String>[];
      i++;
      while (i < lines.length && !_fence.hasMatch(lines[i])) {
        code.add(lines[i++]);
      }
      i++; // the closing fence
      out.add(MdCode(code.join('\n')));
      continue;
    }

    if (line.trim().isEmpty) {
      flush();
      i++;
      continue;
    }

    final h = _heading.firstMatch(line);
    if (h != null) {
      flush();
      out.add(MdHeading(h.group(1)!.length, h.group(2)!));
      i++;
      continue;
    }

    if (line.trimLeft().startsWith('|') &&
        i + 1 < lines.length &&
        _tableRule.hasMatch(lines[i + 1])) {
      flush();
      final header = _cells(line);
      i += 2;
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
        rows.add(_cells(lines[i++]));
      }
      out.add(MdTable(header, rows));
      continue;
    }

    final m = _item.firstMatch(line);
    if (m != null) {
      flush();
      final depth = m.group(1)!.length ~/ 2;
      final marker = m.group(2)!;
      final text = StringBuffer(m.group(3)!);
      i++;
      // Lines indented under the item belong to it.
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          lines[i].startsWith(RegExp(r'\s{2,}')) &&
          !_item.hasMatch(lines[i])) {
        text.write(' ${lines[i].trim()}');
        i++;
      }
      out.add(
        MdListItem(
          RegExp(r'^\d').hasMatch(marker) ? marker : '•',
          depth,
          '$text',
        ),
      );
      continue;
    }

    para.add(line.trim());
    i++;
  }
  flush();
  return out;
}

/// A piece of text with one style, from [parseInline].
class MdSpan {
  const MdSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.link,
  });
  final String text;
  final bool bold;
  final bool italic;
  final bool code;

  /// Where a link points. Shown, not followed.
  final String? link;

  @override
  String toString() =>
      'MdSpan($text${bold ? ' b' : ''}${italic ? ' i' : ''}'
      '${code ? ' c' : ''}${link != null ? ' ->$link' : ''})';
}

final _inline = RegExp(
  r'`([^`]+)`|\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)]+)\)|(?<![\w*])\*([^*\s][^*]*?)\*(?![\w*])',
);

/// Splits one line of text into styled pieces.
List<MdSpan> parseInline(String text) {
  final out = <MdSpan>[];
  var at = 0;
  for (final m in _inline.allMatches(text)) {
    if (m.start > at) out.add(MdSpan(text.substring(at, m.start)));
    if (m.group(1) != null) {
      out.add(MdSpan(m.group(1)!, code: true));
    } else if (m.group(2) != null) {
      // Bold may hold code or a link of its own.
      for (final s in parseInline(m.group(2)!)) {
        out.add(
          MdSpan(
            s.text,
            bold: true,
            italic: s.italic,
            code: s.code,
            link: s.link,
          ),
        );
      }
    } else if (m.group(3) != null) {
      out.add(MdSpan(m.group(3)!, link: m.group(4)));
    } else {
      out.add(MdSpan(m.group(5)!, italic: true));
    }
    at = m.end;
  }
  if (at < text.length) out.add(MdSpan(text.substring(at)));
  return out;
}

/// Renders Markdown [source].
class HaulMarkdown extends StatelessWidget {
  const HaulMarkdown(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final blocks = parseMarkdown(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : _gap(blocks[i - 1], blocks[i]),
            ),
            child: _build(theme, blocks[i]),
          ),
      ],
    );
  }

  static double _gap(MdBlock before, MdBlock now) {
    if (before is MdListItem && now is MdListItem) return 4;
    if (now is MdHeading) return before is MdHeading ? 6 : 20;
    return 10;
  }

  Widget _build(HaulTheme theme, MdBlock block) {
    switch (block) {
      case MdHeading():
        final style = switch (block.level) {
          1 => theme.text.viewTitle,
          2 => theme.text.heading.copyWith(fontSize: 17),
          _ => theme.text.heading,
        };
        return Text.rich(_spans(theme, block.text, style));
      case MdParagraph():
        return Text.rich(_spans(theme, block.text, theme.text.body));
      case MdListItem():
        return Padding(
          padding: EdgeInsets.only(left: 6.0 + block.depth * 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(block.marker, style: theme.text.secondary),
              ),
              Expanded(
                child: Text.rich(_spans(theme, block.text, theme.text.body)),
              ),
            ],
          ),
        );
      case MdCode():
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colors.bgSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.colors.borderSubtle),
          ),
          child: Text(block.text, style: _mono(theme.text.body)),
        );
      case MdTable():
        return _table(theme, block);
    }
  }

  Widget _table(HaulTheme theme, MdTable t) {
    Widget row(List<String> cells, {required bool header, required bool last}) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: theme.colors.borderSubtle)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < t.header.length; c++)
                Expanded(
                  // The first column is a short name; the rest is prose.
                  flex: c == 0 ? 2 : 5,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text.rich(
                      _spans(
                        theme,
                        c < cells.length ? cells[c] : '',
                        header ? theme.text.bodyStrong : theme.text.body,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colors.borderSubtle),
      ),
      child: Column(
        children: [
          row(t.header, header: true, last: false),
          for (var r = 0; r < t.rows.length; r++)
            row(t.rows[r], header: false, last: r == t.rows.length - 1),
        ],
      ),
    );
  }

  static TextStyle _mono(TextStyle base) =>
      base.copyWith(fontFamily: 'Menlo', fontSize: 12);

  static TextSpan _spans(HaulTheme theme, String text, TextStyle base) {
    return TextSpan(
      style: base,
      children: [
        for (final s in parseInline(text))
          TextSpan(
            text: s.text,
            style: TextStyle(
              fontWeight: s.bold ? FontWeight.w700 : null,
              fontStyle: s.italic ? FontStyle.italic : null,
              fontFamily: s.code ? 'Menlo' : null,
              fontSize: s.code ? (base.fontSize ?? 13) - 1 : null,
              color: s.link != null ? theme.colors.accentText : null,
              backgroundColor: s.code ? theme.colors.bgSurface : null,
            ),
          ),
      ],
    );
  }
}
