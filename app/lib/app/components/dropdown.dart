import 'package:flutter/widgets.dart';

import '../theme/haul_theme.dart';
import 'button.dart';
import 'haul_icon.dart';
import 'menu.dart';
import 'pressable.dart';

class HaulDropdownItem<T> {
  const HaulDropdownItem(this.value, this.label);
  final T value;
  final String label;
}

/// A button that opens a menu of choices and shows the chosen one.
class HaulDropdown<T> extends StatelessWidget {
  const HaulDropdown({
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint = 'Choose',
    this.width = 180,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final List<HaulDropdownItem<T>> items;
  final T? value;

  /// Null disables the dropdown.
  final ValueChanged<T>? onChanged;
  final String hint;
  final double width;
  final bool autofocus;
  final FocusNode? focusNode;

  Future<void> _open(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    return showHaulMenu(
      context,
      anchor: origin & box.size,
      minWidth: width,
      entries: [
        for (final item in items)
          HaulMenuItem(
            label: item.label,
            checked: item.value == value,
            onSelected: () => onChanged?.call(item.value),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    String? label;
    for (final i in items) {
      if (i.value == value) label = i.label;
    }
    return Builder(
      builder: (context) => HaulPressable(
        onPressed: onChanged == null ? null : () => _open(context),
        autofocus: autofocus,
        focusNode: focusNode,
        semanticLabel: label ?? hint,
        scale: false,
        builder: (context, s) => Opacity(
          opacity: s.enabled ? 1 : 0.4,
          child: FadeBox(
            color: s.hovered ? c.bgElevated : c.bgSurface,
            radius: HaulRadii.control,
            border: Border.all(color: c.borderSubtle),
            height: haulControlHeight,
            width: width,
            padding: const EdgeInsets.only(left: 10, right: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.text.body.copyWith(
                      color: label == null ? c.textSecondary : c.textPrimary,
                    ),
                  ),
                ),
                HaulIcon(HaulIcons.caretDown, size: 12, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
