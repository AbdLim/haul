import 'package:flutter/widgets.dart';

import '../../app/components/components.dart';
import '../../app/theme/haul_theme.dart';
import '../add_download/add_download_cubit.dart';

/// Asks for a fresh link for a download whose old one has expired. Returns the
/// new link, or null if the person backed out.
Future<Uri?> showRefreshLinkDialog(BuildContext context, {String? fileName}) {
  return showHaulDialog<Uri>(
    context,
    builder: (ctx) => _RefreshLinkDialog(fileName: fileName),
  );
}

class _RefreshLinkDialog extends StatefulWidget {
  const _RefreshLinkDialog({this.fileName});
  final String? fileName;

  @override
  State<_RefreshLinkDialog> createState() => _RefreshLinkDialogState();
}

class _RefreshLinkDialogState extends State<_RefreshLinkDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final uri = AddDownloadCubit.parseLink(_controller.text);
    if (uri == null) {
      setState(() {
        _error = _controller.text.trim().isEmpty
            ? 'Paste the new link'
            : 'That does not look like a link';
      });
      return;
    }
    Navigator.of(context).pop(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return HaulDialog(
      title: 'Refresh the link',
      width: 460,
      actions: [
        HaulButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        HaulButton(
          label: 'Refresh',
          kind: HaulButtonKind.primary,
          onPressed: _submit,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.fileName == null
                ? 'The old link has expired. Paste a new one for the same file and the download carries on from where it stopped.'
                : 'The link for ${widget.fileName} has expired. Paste a new one for the same file and the download carries on from where it stopped.',
            style: theme.text.secondary,
          ),
          const SizedBox(height: HaulSpace.m),
          HaulTextField(
            controller: _controller,
            autofocus: true,
            hint: 'https://example.com/file.zip',
            semanticLabel: 'New link',
            invalid: _error != null,
            leading: HaulIcon(
              HaulIcons.link,
              color: theme.colors.textSecondary,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                style: theme.text.caption.copyWith(color: theme.colors.danger),
              ),
            ),
        ],
      ),
    );
  }
}
