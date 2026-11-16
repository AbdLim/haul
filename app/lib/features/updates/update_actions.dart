import 'dart:math';

import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/shell_cubit.dart';
import '../../app/cubits/update_cubit.dart';
import '../../app/dependencies.dart';
import '../../app/format.dart';
import '../../app/theme/haul_theme.dart';
import '../../services/updates/update_checker.dart';

/// Downloads the new DMG with Haul's own engine, into the folder DMGs go to,
/// and shows it in the list. When it finishes, the usual "finished" banner
/// appears and clicking it reveals the file; opening the DMG and dragging Haul
/// to Applications finishes the update.
Future<void> downloadUpdate(BuildContext context, UpdateInfo info) async {
  final url = info.downloadUrl;
  if (url == null) {
    await context.read<AppDependencies>().platform.openUrl(info.pageUrl);
    return;
  }
  final deps = context.read<AppDependencies>();
  final shell = context.read<ShellCubit>();
  final name = info.fileName ?? 'Haul-${info.version}.dmg';
  final category = await deps.categories.categoryFor(name);
  await deps.downloads.add(
    DownloadRequest(
      id: 'update-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}',
      url: Uri.parse(url),
      saveDir: category.saveDir,
      fileName: name,
    ),
    source: 'update',
    categoryId: category.id,
  );
  shell.showDownloads();
}

/// The release notes in a dialog, with the choices that go with them.
Future<void> showWhatsNew(BuildContext context, UpdateInfo info) {
  final cubit = context.read<UpdateCubit>();
  final deps = context.read<AppDependencies>();
  return showHaulDialog<void>(
    context,
    builder: (ctx) {
      final theme = HaulTheme.of(ctx);
      return HaulDialog(
        title: 'Haul ${info.version}',
        width: 680,
        actions: [
          HaulButton(
            label: 'Skip this version',
            kind: HaulButtonKind.ghost,
            onPressed: () {
              cubit.skip();
              Navigator.of(ctx).pop();
            },
          ),
          HaulButton(
            label: 'View on GitHub',
            onPressed: () => deps.platform.openUrl(info.pageUrl),
          ),
          HaulButton(
            label: info.downloadUrl == null
                ? 'Open the release page'
                : 'Download',
            kind: HaulButtonKind.primary,
            autofocus: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              downloadUpdate(context, info);
            },
          ),
        ],
        child: SizedBox(
          height: 420,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(right: HaulSpace.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      'Released ${_date(info.publishedAt)}',
                      if (info.size != null) formatBytes(info.size!),
                    ].where((p) => !p.endsWith(' ')).join(' · '),
                    style: theme.text.caption,
                  ),
                  const SizedBox(height: HaulSpace.m),
                  info.notes.trim().isEmpty
                      ? Text(
                          'No notes for this release.',
                          style: theme.text.secondary,
                        )
                      : HaulMarkdown(info.notes, onLink: deps.platform.openUrl),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

String _date(DateTime? d) {
  if (d == null) return '';
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];
  final l = d.toLocal();
  return '${l.day} ${months[l.month - 1]} ${l.year}';
}
