import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/cubits/setting_cubit.dart';
import '../../app/dependencies.dart';
import '../../data/setting_key.dart';

/// Builds from one setting's current value, and again whenever it changes.
/// Controls write back with `context.read<AppDependencies>().settings.set`.
class SettingBuilder<T> extends StatefulWidget {
  const SettingBuilder({
    required this.settingKey,
    required this.builder,
    super.key,
  });

  final SettingKey<T> settingKey;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<SettingBuilder<T>> createState() => _SettingBuilderState<T>();
}

class _SettingBuilderState<T> extends State<SettingBuilder<T>> {
  SettingCubit<T>? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= SettingCubit<T>(
      context.read<AppDependencies>().settings,
      widget.settingKey,
    );
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SettingCubit<T>, T>(bloc: _cubit, builder: widget.builder);
}
