import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/format.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/categories_repository.dart';
import 'add_download_cubit.dart';

/// The Add URL dialog: the link, a probe of what it points at, the file name,
/// the category and folder, and how many connections to use.
class AddDownloadDialog extends StatefulWidget {
  const AddDownloadDialog({
    required this.categories,
    this.readClipboard = true,
    super.key,
  });

  final List<DownloadCategory> categories;

  /// Whether to offer a link found on the clipboard. Tests turn it off.
  final bool readClipboard;

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> {
  late final TextEditingController _url;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final state = context.read<AddDownloadCubit>().state;
    _url = TextEditingController(text: state.url);
    _name = TextEditingController(text: state.fileName);
    if (_url.text.isEmpty && widget.readClipboard) _offerClipboard();
  }

  /// If the clipboard holds a web link, start with it.
  Future<void> _offerClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || _url.text.isNotEmpty) return;
    if (AddDownloadCubit.parseLink(text) == null) return;
    _url.text = text;
    context.read<AddDownloadCubit>().setUrl(text);
  }

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _start({DuplicateChoice? choice}) async {
    final cubit = context.read<AddDownloadCubit>();
    final outcome = await cubit.submit(choice: choice);
    if (!mounted) return;
    if (outcome == AddOutcome.added || outcome == AddOutcome.resumedExisting) {
      Navigator.of(context).pop(outcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    final cubit = context.read<AddDownloadCubit>();
    return BlocBuilder<AddDownloadCubit, AddDownloadState>(
      builder: (context, s) {
        final duplicate = s.duplicate;
        return HaulDialog(
          title: 'Add a download',
          width: 520,
          actions: [
            HaulButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (duplicate != null) ...[
              HaulButton(
                label: 'Resume existing',
                onPressed: () => _start(choice: DuplicateChoice.resumeExisting),
              ),
              HaulButton(
                label: 'Add a copy',
                kind: HaulButtonKind.primary,
                onPressed: () => _start(choice: DuplicateChoice.addCopy),
              ),
            ] else
              HaulButton(
                label: 'Start',
                kind: HaulButtonKind.primary,
                onPressed: _start,
              ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cubit.handoff != null) ...[
                Text(
                  'Sent by ${cubit.handoff!.browserName}',
                  style: theme.text.caption.copyWith(color: c.accent),
                ),
                const SizedBox(height: HaulSpace.s),
              ],
              _Label('Link', theme),
              HaulTextField(
                controller: _url,
                autofocus: true,
                hint: 'https://example.com/file.zip',
                semanticLabel: 'Link',
                invalid: s.urlError != null,
                leading: HaulIcon(HaulIcons.link, color: c.textSecondary),
                onChanged: cubit.setUrl,
                onSubmitted: (_) => _start(),
              ),
              _Below(text: s.urlError, color: c.danger, theme: theme),
              if (s.urlError == null) _Detected(state: s),
              const SizedBox(height: HaulSpace.m),
              _Label('File name', theme),
              HaulTextField(
                controller: _name,
                hint: cubit.effectiveName.isEmpty
                    ? 'Detected automatically'
                    : cubit.effectiveName,
                semanticLabel: 'File name',
                onChanged: cubit.setFileName,
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: HaulSpace.m),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Category', theme),
                        HaulDropdown<int>(
                          width: 240,
                          value: s.categoryId,
                          items: [
                            for (final cat in widget.categories)
                              HaulDropdownItem(cat.id, cat.name),
                          ],
                          onChanged: cubit.setCategory,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: HaulSpace.m),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Connections', theme),
                      HaulDropdown<int>(
                        width: 120,
                        value: s.connections,
                        items: [
                          for (final n in connectionChoices)
                            HaulDropdownItem(n, '$n'),
                        ],
                        onChanged: cubit.setConnections,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: HaulSpace.m),
              _Label('Save to', theme),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shortenPath(s.saveDir ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.body,
                    ),
                  ),
                  const SizedBox(width: HaulSpace.s),
                  HaulButton(
                    label: 'Choose…',
                    icon: HaulIcons.folder,
                    onPressed: cubit.chooseFolder,
                  ),
                ],
              ),
              if (duplicate != null) ...[
                const SizedBox(height: HaulSpace.m),
                _DuplicateNotice(theme: theme),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A long folder path cut from the left, so the end, which says most, stays.
String shortenPath(String path, {int max = 52}) =>
    path.length <= max ? path : '…${path.substring(path.length - (max - 1))}';

class _Label extends StatelessWidget {
  const _Label(this.text, this.theme);
  final String text;
  final HaulTheme theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: theme.text.caption),
  );
}

class _Below extends StatelessWidget {
  const _Below({required this.text, required this.color, required this.theme});
  final String? text;
  final Color color;
  final HaulTheme theme;

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text!, style: theme.text.caption.copyWith(color: color)),
    );
  }
}

/// What the probe found, under the link field.
class _Detected extends StatelessWidget {
  const _Detected({required this.state});
  final AddDownloadState state;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    switch (state.probe) {
      case ProbeStatus.idle:
        return const SizedBox.shrink();
      case ProbeStatus.checking:
        return _Below(
          text: 'Checking the link…',
          color: c.textSecondary,
          theme: theme,
        );
      case ProbeStatus.failed:
        return _Below(text: state.probeError, color: c.danger, theme: theme);
      case ProbeStatus.found:
        final info = state.info!;
        final size = info.size == null
            ? 'size unknown'
            : formatBytes(info.size!);
        final resume = info.supportsRanges
            ? ''
            : ' · cannot be resumed once paused';
        return _Below(
          text: '${info.fileName} · $size$resume',
          color: c.textSecondary,
          theme: theme,
        );
    }
  }
}

class _DuplicateNotice extends StatelessWidget {
  const _DuplicateNotice({required this.theme});
  final HaulTheme theme;

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.warning.withAlpha(0x1F),
        borderRadius: BorderRadius.circular(HaulRadii.control),
        border: Border.all(color: c.warning.withAlpha(0x66)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(HaulSpace.s + 2),
        child: Row(
          children: [
            HaulIcon(HaulIcons.warning, color: c.warning),
            const SizedBox(width: HaulSpace.s),
            Expanded(
              child: Text(
                'This link is already in your list.',
                style: theme.text.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
