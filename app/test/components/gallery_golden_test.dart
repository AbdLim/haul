import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/features/debug/component_gallery.dart';

import '../support/widget_host.dart';

/// Pictures of every component in each theme. They are drawn with the test
/// font, so the text is blocks; the shapes, colours and spacing are what they
/// guard. Regenerate with `flutter test --update-goldens` after an intended
/// visual change, and look at the diff before committing it.
void main() {
  for (final mode in [AppThemeMode.dark, AppThemeMode.light]) {
    haulTest('gallery in ${mode.name}', (tester) async {
      await pumpHaul(
        tester,
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: SizedBox(
            width: 520,
            height: 1250,
            child: GalleryPanel(mode: mode),
          ),
        ),
        mode: mode,
        size: const Size(560, 1290),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('shot')),
        matchesGoldenFile('goldens/gallery_${mode.name}.png'),
      );
    });
  }

  haulTest('the whole gallery builds without errors', (tester) async {
    await pumpHaul(
      tester,
      const SizedBox(width: 1100, height: 1250, child: ComponentGallery()),
      size: const Size(1140, 1290),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
