import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_window_utils/widgets/transparent_macos_sidebar.dart';

import '../../app/cubits/shell_cubit.dart';
import '../../app/motion/view_switch.dart';
import '../../app/theme/haul_theme.dart';
import '../../services/system/window_chrome.dart';
import 'header_drag_area.dart';
import 'shell_metrics.dart';

/// The window's layout: a translucent sidebar on the left, then a header
/// band over the download list, and a detail panel that slides in on the
/// right. The pieces fill in over the next tasks; this is the frame.
class ShellPage extends StatelessWidget {
  const ShellPage({
    required this.chrome,
    this.native = true,
    this.sidebar,
    this.header,
    this.content,
    this.detail,
    this.settings,
    super.key,
  });

  final WindowChrome chrome;

  /// False in tests: no native blur and no native window dragging.
  final bool native;
  final Widget? sidebar;
  final Widget? header;
  final Widget? content;
  final Widget? detail;
  final Widget? settings;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final inSettings = context.select<ShellCubit, bool>(
      (c) => c.state.section == MainSection.settings,
    );

    final sidebarBody = ColoredBox(
      color: theme.colors.bgSidebar,
      child: SizedBox(
        width: ShellMetrics.sidebarWidth,
        child: sidebar ?? const SizedBox.shrink(),
      ),
    );

    return ColoredBox(
      color: theme.colors.bgWindow,
      child: Row(
        children: [
          SizedBox(
            width: ShellMetrics.sidebarWidth,
            child: native && chrome.blursSidebar
                ? TransparentMacOSSidebar(child: sidebarBody)
                : sidebarBody,
          ),
          Expanded(
            child: ViewSwitch(
              child: inSettings
                  ? KeyedSubtree(
                      key: const ValueKey('view-settings'),
                      child: settings ?? const SizedBox.shrink(),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('view-downloads'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: ShellMetrics.headerHeight,
                                  child: HeaderDragArea(
                                    enabled: native,
                                    onDoubleTap: chrome.toggleZoom,
                                    child: header ?? const SizedBox.expand(),
                                  ),
                                ),
                                Expanded(
                                  child: content ?? const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                          ?detail,
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
