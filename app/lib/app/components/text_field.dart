import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/haul_theme.dart';
import 'button.dart';

/// A single-line text box built on `EditableText`. Replaces the stock text
/// field: a quiet outline that turns accent-coloured while it has focus.
class HaulTextField extends StatefulWidget {
  const HaulTextField({
    this.controller,
    this.focusNode,
    this.hint,
    this.leading,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.enabled = true,
    this.invalid = false,
    this.autofocus = false,
    this.keyboardType,
    this.inputFormatters,
    this.semanticLabel,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;

  /// Typically a [HaulIcon], shown inside the left edge.
  final Widget? leading;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool enabled;

  /// Shows the outline in the danger colour.
  final bool invalid;
  final bool autofocus;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? semanticLabel;

  @override
  State<HaulTextField> createState() => _HaulTextFieldState();
}

class _HaulTextFieldState extends State<HaulTextField>
    implements TextSelectionGestureDetectorBuilderDelegate {
  final GlobalKey<EditableTextState> _editable = GlobalKey();
  late final TextSelectionGestureDetectorBuilder _gestures =
      TextSelectionGestureDetectorBuilder(delegate: this);

  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  bool _hovered = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  GlobalKey<EditableTextState> get editableTextKey => _editable;
  @override
  bool get forcePressEnabled => false;
  @override
  bool get selectionEnabled => true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(HaulTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_rebuild);
      _focus.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_rebuild);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    final focused = _focus.hasFocus;
    final border = widget.invalid
        ? c.danger
        : focused
        ? c.accent
        : (_hovered ? c.textSecondary.withAlpha(0x80) : c.borderSubtle);

    final field = _gestures.buildGestureDetector(
      behavior: HitTestBehavior.translucent,
      child: EditableText(
        key: _editable,
        controller: _controller,
        focusNode: _focus,
        style: theme.text.body,
        cursorColor: c.accentText,
        backgroundCursorColor: c.borderSubtle,
        selectionColor: c.accent.withAlpha(0x59),
        cursorWidth: 1.5,
        obscureText: widget.obscureText,
        readOnly: !widget.enabled,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        rendererIgnoresPointer: true,
        mouseCursor: SystemMouseCursors.text,
      ),
    );

    return Semantics(
      textField: true,
      label: widget.semanticLabel ?? widget.hint,
      enabled: widget.enabled,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.hover),
            curve: Motion.easeOut,
            height: haulControlHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(HaulRadii.control),
              border: Border.all(color: border, width: focused ? 1.5 : 1),
            ),
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (widget.hint != null)
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, v, _) => v.text.isEmpty
                              ? IgnorePointer(
                                  child: Text(
                                    widget.hint!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.text.body.copyWith(
                                      color: c.textSecondary.withAlpha(0xB0),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      field,
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 6),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
