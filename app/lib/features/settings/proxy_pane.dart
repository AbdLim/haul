import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/dependencies.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/setting_keys.dart';
import '../../services/network/proxy_tester.dart';
import '../../services/system/secret_store.dart';
import 'chip_list_editor.dart';
import 'setting_builder.dart';
import 'settings_widgets.dart';
import 'synced_text_field.dart';

class ProxyPane extends StatelessWidget {
  const ProxyPane({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppDependencies>().settings;
    return SettingBuilder<ProxyMode>(
      settingKey: Keys.proxyMode,
      builder: (context, mode) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            title: 'Proxy',
            children: [
              SettingsRow(
                label: 'Use',
                help: 'Only HTTP proxies are supported.',
                control: SizedBox(
                  width: 300,
                  child: HaulSegmentedControl<ProxyMode>(
                    segments: const [
                      HaulSegment(ProxyMode.none, 'No proxy'),
                      HaulSegment(ProxyMode.system, 'System'),
                      HaulSegment(ProxyMode.manual, 'Manual'),
                    ],
                    value: mode,
                    onChanged: (m) => settings.set(Keys.proxyMode, m),
                  ),
                ),
              ),
              if (mode == ProxyMode.system) const _SystemProxyLine(),
            ],
          ),
          if (mode == ProxyMode.manual) const _ManualProxy(),
          if (mode != ProxyMode.none) ...[
            SettingsSection(
              title: 'Connect directly to',
              children: [
                SettingBuilder<List<String>>(
                  settingKey: Keys.proxyBypass,
                  builder: (context, list) => Padding(
                    padding: const EdgeInsets.all(HaulSpace.m),
                    child: ChipListEditor(
                      values: list,
                      hint: 'Add a site, or *.example.com for a whole domain',
                      semanticLabel: 'Add a site to bypass',
                      emptyText: 'No sites. Everything goes through the proxy.',
                      onAdd: (text) {
                        final host = text.trim().toLowerCase();
                        if (host.isEmpty || list.contains(host)) return;
                        settings.set(Keys.proxyBypass, [...list, host]);
                      },
                      onRemove: (h) => settings.set(Keys.proxyBypass, [
                        for (final e in list)
                          if (e != h) e,
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            const _TestProxy(),
          ],
        ],
      ),
    );
  }
}

class _SystemProxyLine extends StatelessWidget {
  const _SystemProxyLine();

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final resolver = context.read<AppDependencies>().systemProxy;
    return SettingsRow(
      label: 'Your Mac\'s proxy',
      control: FutureBuilder<ProxyConfig?>(
        future: resolver?.resolve(),
        builder: (context, snap) => Text(
          snap.connectionState != ConnectionState.done
              ? 'Looking…'
              : (snap.data == null
                    ? 'None set'
                    : '${snap.data!.host}:${snap.data!.port}'),
          style: theme.text.secondary,
        ),
      ),
    );
  }
}

class _ManualProxy extends StatefulWidget {
  const _ManualProxy();

  @override
  State<_ManualProxy> createState() => _ManualProxyState();
}

class _ManualProxyState extends State<_ManualProxy> {
  Timer? _save;
  bool? _hasPassword;

  @override
  void initState() {
    super.initState();
    final deps = context.read<AppDependencies>();
    deps.secrets.read(proxyPasswordKey).then((v) {
      if (mounted) setState(() => _hasPassword = v != null && v.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _save?.cancel();
    super.dispose();
  }

  /// The password goes to the Keychain a moment after typing stops.
  void _password(String text) {
    final deps = context.read<AppDependencies>();
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 400), () async {
      if (text.isEmpty) {
        await deps.secrets.delete(proxyPasswordKey);
      } else {
        await deps.secrets.write(proxyPasswordKey, text);
      }
      deps.networkSync?.passwordChanged();
      if (mounted) setState(() => _hasPassword = text.isNotEmpty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppDependencies>().settings;
    return SettingsSection(
      title: 'Manual proxy',
      children: [
        SettingBuilder<String?>(
          settingKey: Keys.proxyHost,
          builder: (context, host) => SettingsRow(
            label: 'Host',
            control: SizedBox(
              width: 260,
              child: SyncedTextField(
                label: 'Proxy host',
                hint: 'proxy.example.com',
                value: host ?? '',
                onChanged: (v) => settings.set(
                  Keys.proxyHost,
                  v.trim().isEmpty ? null : v.trim(),
                ),
              ),
            ),
          ),
        ),
        SettingBuilder<int?>(
          settingKey: Keys.proxyPort,
          builder: (context, port) => SettingsRow(
            label: 'Port',
            control: SizedBox(
              width: 100,
              child: SyncedTextField(
                label: 'Proxy port',
                hint: '8080',
                digitsOnly: true,
                value: port == null ? '' : '$port',
                onChanged: (v) => settings.set(Keys.proxyPort, int.tryParse(v)),
              ),
            ),
          ),
        ),
        SettingBuilder<String?>(
          settingKey: Keys.proxyUsername,
          builder: (context, user) => SettingsRow(
            label: 'User name',
            help: 'Leave empty if the proxy needs no login.',
            control: SizedBox(
              width: 260,
              child: SyncedTextField(
                label: 'Proxy user name',
                hint: 'Optional',
                value: user ?? '',
                onChanged: (v) => settings.set(
                  Keys.proxyUsername,
                  v.trim().isEmpty ? null : v.trim(),
                ),
              ),
            ),
          ),
        ),
        SettingsRow(
          label: 'Password',
          help: _hasPassword == true
              ? 'A password is saved in your Keychain. Type to replace it, '
                    'or clear the box and type nothing to keep it.'
              : 'Saved in your Keychain, never shown.',
          control: SizedBox(
            width: 260,
            child: HaulTextField(
              hint: _hasPassword == true ? '••••••••' : 'Optional',
              semanticLabel: 'Proxy password',
              obscureText: true,
              onChanged: _password,
            ),
          ),
        ),
      ],
    );
  }
}

class _TestProxy extends StatefulWidget {
  const _TestProxy();

  @override
  State<_TestProxy> createState() => _TestProxyState();
}

class _TestProxyState extends State<_TestProxy> {
  bool _running = false;
  ProxyTestResult? _result;

  Future<void> _run() async {
    final deps = context.read<AppDependencies>();
    final tester = deps.proxyTester;
    final sync = deps.networkSync;
    if (tester == null || sync == null) return;
    setState(() {
      _running = true;
      _result = null;
    });
    final mode = deps.settings.get(Keys.proxyMode);
    final proxy = mode == ProxyMode.system
        ? await deps.systemProxy?.resolve()
        : await sync.manualProxy();
    final ProxyTestResult result;
    if (proxy == null) {
      result = ProxyTestResult.failed(
        mode == ProxyMode.system
            ? 'Your Mac has no proxy set'
            : 'Enter a host and a port first',
      );
    } else {
      result = await tester.test(proxy);
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final r = _result;
    return Row(
      children: [
        HaulButton(
          label: _running ? 'Testing…' : 'Test proxy',
          onPressed: _running ? null : _run,
        ),
        const SizedBox(width: HaulSpace.m),
        if (r != null)
          Expanded(
            child: Text(
              r.message,
              style: theme.text.body.copyWith(
                color: r.ok ? theme.colors.success : theme.colors.danger,
              ),
            ),
          ),
      ],
    );
  }
}
