import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/dependencies.dart';
import '../../app/platform_names.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/site_logins_repository.dart';
import '../../data/site_rules_repository.dart';
import 'settings_widgets.dart';

class SiteLoginsPane extends StatelessWidget {
  const SiteLoginsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDependencies>();
    final theme = HaulTheme.of(context);
    return StreamBuilder<List<SiteLoginEntry>>(
      stream: deps.siteLogins.watchAll(),
      builder: (context, snap) {
        final logins = snap.data ?? const <SiteLoginEntry>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsSection(
              title: 'Sites that need a login',
              children: [
                if (logins.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(HaulSpace.m),
                    child: Text(
                      'No logins. When a site asks for one, add it here and '
                      'retry the download. Passwords are kept in '
                      '${PlatformNames.credentialStore} and are never shown.',
                      style: theme.text.caption,
                    ),
                  ),
                for (final l in logins)
                  SettingsRow(
                    label: l.host,
                    help: l.username,
                    control: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HaulButton(
                          label: 'Edit',
                          onPressed: () =>
                              showLoginDialog(context, existing: l),
                        ),
                        const SizedBox(width: HaulSpace.s),
                        HaulIconButton(
                          icon: HaulIcons.trash,
                          tooltip: 'Delete the login for ${l.host}',
                          onPressed: () => _delete(context, l),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: HaulButton(
                label: 'Add login',
                icon: HaulIcons.plus,
                onPressed: () => showLoginDialog(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, SiteLoginEntry l) async {
    final deps = context.read<AppDependencies>();
    final yes = await confirm(
      context,
      title: 'Delete this login?',
      message:
          'Haul will stop signing in to ${l.host}. '
          'Its saved password is removed from ${PlatformNames.credentialStore}.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (yes) await deps.siteLogins.delete(l.host);
  }
}

/// Adds a login, or edits [existing]. When editing, the saved password is not
/// shown: leaving the box empty keeps it.
Future<void> showLoginDialog(
  BuildContext context, {
  SiteLoginEntry? existing,
}) async {
  final deps = context.read<AppDependencies>();
  await showHaulDialog<void>(
    context,
    builder: (_) => _LoginDialog(deps: deps, existing: existing),
  );
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog({required this.deps, this.existing});

  final AppDependencies deps;
  final SiteLoginEntry? existing;

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  late final _host = TextEditingController(text: widget.existing?.host ?? '');
  late final _user = TextEditingController(
    text: widget.existing?.username ?? '',
  );
  final _password = TextEditingController();
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _host.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final host = SiteRulesRepository.hostFrom(_host.text);
    final user = _user.text.trim();
    final password = _password.text;
    String? error;
    if (host.isEmpty) {
      error = 'Enter the site, such as example.com';
    } else if (user.isEmpty) {
      error = 'Enter a user name';
    } else if (!_editing && password.isEmpty) {
      error = 'Enter a password';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final logins = widget.deps.siteLogins;
    if (_editing && password.isEmpty) {
      await logins.rename(host, user);
    } else {
      await logins.save(host, user, password);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return HaulDialog(
      title: _editing ? 'Edit login' : 'Add login',
      actions: [
        HaulButton(
          label: 'Cancel',
          kind: HaulButtonKind.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        HaulButton(
          label: 'Save',
          kind: HaulButtonKind.primary,
          onPressed: _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HaulTextField(
            controller: _host,
            hint: 'Site, such as example.com',
            semanticLabel: 'Site',
            enabled: !_editing,
            autofocus: !_editing,
          ),
          const SizedBox(height: HaulSpace.s),
          HaulTextField(
            controller: _user,
            hint: 'User name',
            semanticLabel: 'User name',
            autofocus: _editing,
          ),
          const SizedBox(height: HaulSpace.s),
          HaulTextField(
            controller: _password,
            hint: _editing
                ? 'Leave empty to keep the saved password'
                : 'Password',
            semanticLabel: 'Password',
            obscureText: true,
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: HaulSpace.s),
            Text(
              _error!,
              style: theme.text.caption.copyWith(color: theme.colors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
