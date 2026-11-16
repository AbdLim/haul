import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app/components/components.dart';

/// A text box for a setting. It saves as the person types, and follows the
/// setting when it is changed from outside (a reset) without rewriting its own
/// echo, which would move the cursor.
class SyncedTextField extends StatefulWidget {
  const SyncedTextField({
    required this.value,
    required this.onChanged,
    required this.label,
    this.hint,
    this.digitsOnly = false,
    this.obscure = false,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final String? hint;
  final bool digitsOnly;
  final bool obscure;

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(SyncedTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text.trim() && widget.value != old.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HaulTextField(
    controller: _controller,
    hint: widget.hint ?? widget.label,
    semanticLabel: widget.label,
    obscureText: widget.obscure,
    keyboardType: widget.digitsOnly ? TextInputType.number : null,
    inputFormatters: widget.digitsOnly
        ? [FilteringTextInputFormatter.digitsOnly]
        : null,
    onChanged: widget.onChanged,
  );
}
