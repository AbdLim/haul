import 'dart:ui';

/// Every colour in the app, named by role.
/// Nothing outside this file chooses a colour.
class HaulColors {
  const HaulColors({
    required this.bgWindow,
    required this.bgSidebar,
    required this.bgSurface,
    required this.bgElevated,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.progressTrack,
  });

  /// The window background.
  final Color bgWindow;

  /// The sidebar. 80 percent opaque so the window blur shows through.
  final Color bgSidebar;

  /// Rows on hover, and cards.
  final Color bgSurface;

  /// Dialogs and menus.
  final Color bgElevated;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;

  /// Fills, progress and the graph.
  final Color accent;

  /// Accent-coloured text and icons.
  final Color accentText;

  /// Text on an accent fill.
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color progressTrack;

  static const dark = HaulColors(
    bgWindow: Color(0xFF14171C),
    bgSidebar: Color(0xCC101216), // #101216 at 80 percent
    bgSurface: Color(0xFF1C2027),
    bgElevated: Color(0xFF232831),
    borderSubtle: Color(0xFF2A303A),
    textPrimary: Color(0xFFF4F5F7),
    textSecondary: Color(0xFFA3ABB8),
    accent: Color(0xFFF25C05),
    accentText: Color(0xFFFF7A2E),
    onAccent: Color(0xFF14171C),
    success: Color(0xFF2BC275),
    warning: Color(0xFFFFB400),
    danger: Color(0xFFFF5D5D),
    progressTrack: Color(0xFF2A303A),
  );

  static const light = HaulColors(
    bgWindow: Color(0xFFF6F7F9),
    bgSidebar: Color(0xCCECEEF2), // #ECEEF2 at 80 percent
    bgSurface: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFFFFFFF),
    borderSubtle: Color(0xFFE1E4EA),
    textPrimary: Color(0xFF14171C),
    textSecondary: Color(0xFF4A5360),
    accent: Color(0xFFF25C05),
    accentText: Color(0xFFC44700),
    onAccent: Color(0xFF14171C),
    success: Color(0xFF12894A),
    warning: Color(0xFF9A6B00),
    danger: Color(0xFFC92A2A),
    progressTrack: Color(0xFFE1E4EA),
  );

  /// Token name to colour, for tests and for the debug gallery.
  Map<String, Color> toMap() => {
    'bg.window': bgWindow,
    'bg.sidebar': bgSidebar,
    'bg.surface': bgSurface,
    'bg.elevated': bgElevated,
    'border.subtle': borderSubtle,
    'text.primary': textPrimary,
    'text.secondary': textSecondary,
    'accent': accent,
    'accent.text': accentText,
    'on.accent': onAccent,
    'success': success,
    'warning': warning,
    'danger': danger,
    'progress.track': progressTrack,
  };

  static HaulColors lerp(HaulColors a, HaulColors b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return HaulColors(
      bgWindow: c(a.bgWindow, b.bgWindow),
      bgSidebar: c(a.bgSidebar, b.bgSidebar),
      bgSurface: c(a.bgSurface, b.bgSurface),
      bgElevated: c(a.bgElevated, b.bgElevated),
      borderSubtle: c(a.borderSubtle, b.borderSubtle),
      textPrimary: c(a.textPrimary, b.textPrimary),
      textSecondary: c(a.textSecondary, b.textSecondary),
      accent: c(a.accent, b.accent),
      accentText: c(a.accentText, b.accentText),
      onAccent: c(a.onAccent, b.onAccent),
      success: c(a.success, b.success),
      warning: c(a.warning, b.warning),
      danger: c(a.danger, b.danger),
      progressTrack: c(a.progressTrack, b.progressTrack),
    );
  }
}
