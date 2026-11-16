import 'package:flutter/widgets.dart';

import '../../app/components/components.dart';
import '../../app/theme/haul_theme.dart';

/// A list of short words shown as removable chips, with a box to add more.
/// Used for file extensions and host names.
class ChipListEditor extends StatefulWidget {
  const ChipListEditor({
    required this.values,
    required this.onAdd,
    required this.onRemove,
    required this.hint,
    this.emptyText = 'None',
    this.semanticLabel,
    super.key,
  });

  final List<String> values;

  /// Called with the text as typed. The owner cleans it and decides whether
  /// it is acceptable.
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final String hint;
  final String emptyText;
  final String? semanticLabel;

  @override
  State<ChipListEditor> createState() => _ChipListEditorState();
}

class _ChipListEditorState extends State<ChipListEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.values.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: HaulSpace.s),
            child: Text(widget.emptyText, style: theme.text.caption),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: HaulSpace.s),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in widget.values)
                  HaulChip(label: v, onDeleted: () => widget.onRemove(v)),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: HaulTextField(
                controller: _controller,
                hint: widget.hint,
                semanticLabel: widget.semanticLabel,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: HaulSpace.s),
            HaulButton(label: 'Add', onPressed: _submit),
          ],
        ),
      ],
    );
  }
}
