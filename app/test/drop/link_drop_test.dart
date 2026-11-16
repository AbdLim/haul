import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/commands.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/downloads_cubit.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/features/drop/link_drop_target.dart';
import 'package:haul/features/drop/link_extractor.dart';

import '../support/test_deps.dart';
import '../support/widget_host.dart';

const webloc = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>URL</key>
	<string>https://example.com/files/big.zip?a=1&amp;b=2</string>
</dict>
</plist>
''';

void main() {
  group('LinkExtractor.fromText', () {
    test('finds a link on its own or among words', () {
      expect(
        LinkExtractor.fromText('https://a.com/f.zip'),
        Uri.parse('https://a.com/f.zip'),
      );
      expect(
        LinkExtractor.fromText('grab this: http://a.com/x.iso please'),
        Uri.parse('http://a.com/x.iso'),
      );
      expect(LinkExtractor.fromText('  \n https://a.com/f \n '), isNotNull);
    });

    test('takes the first of several', () {
      expect(
        LinkExtractor.fromText('https://one.com/a https://two.com/b'),
        Uri.parse('https://one.com/a'),
      );
    });

    test('gives nothing when there is no web link', () {
      for (final t in [
        '',
        'hello world',
        'ftp://a.com/file',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'a.com/file.zip',
      ]) {
        expect(LinkExtractor.fromText(t), isNull, reason: t);
      }
    });
  });

  group('shortcut files', () {
    test('a .webloc holds its link in a URL key, with entities decoded', () {
      expect(
        LinkExtractor.fromWebloc(webloc),
        Uri.parse('https://example.com/files/big.zip?a=1&b=2'),
      );
    });

    test('a .webloc with no link, or a bad one, gives nothing', () {
      expect(LinkExtractor.fromWebloc('<plist><dict></dict></plist>'), isNull);
      expect(
        LinkExtractor.fromWebloc('<key>URL</key><string>ftp://x/y</string>'),
        isNull,
      );
    });

    test('a .url file holds URL=', () {
      expect(
        LinkExtractor.fromUrlFile(
          '[InternetShortcut]\r\nURL=https://a.com/f.zip\r\n',
        ),
        Uri.parse('https://a.com/f.zip'),
      );
      expect(LinkExtractor.fromUrlFile('[InternetShortcut]\r\n'), isNull);
      expect(LinkExtractor.fromUrlFile('url = https://a.com/lower'), isNotNull);
    });
  });

  group('LinkExtractor.fromFile', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('drop_'));
    tearDown(() => dir.deleteSync(recursive: true));

    File write(String name, String text) =>
        File('${dir.path}/$name')..writeAsStringSync(text);

    test('reads links from .webloc, .url and text files', () async {
      expect(
        await LinkExtractor.fromFile(write('a.webloc', webloc).path),
        Uri.parse('https://example.com/files/big.zip?a=1&b=2'),
      );
      expect(
        await LinkExtractor.fromFile(
          write('b.url', 'URL=https://b.com/x').path,
        ),
        Uri.parse('https://b.com/x'),
      );
      expect(
        await LinkExtractor.fromFile(
          write('c.txt', 'see https://c.com/y ok').path,
        ),
        Uri.parse('https://c.com/y'),
      );
    });

    test('ignores other kinds of file', () async {
      expect(
        await LinkExtractor.fromFile(
          write('photo.jpg', 'https://a.com/x').path,
        ),
        isNull,
      );
      expect(await LinkExtractor.fromFile('${dir.path}/missing.txt'), isNull);
    });

    test('ignores a big file instead of reading it', () async {
      final big = write('big.txt', 'x' * (LinkExtractor.maxFileBytes + 10));
      expect(await LinkExtractor.fromFile(big.path), isNull);
    });

    test('a file that is not text gives nothing, not an error', () async {
      final f = File('${dir.path}/odd.txt')
        ..writeAsBytesSync([0xff, 0xfe, 0xfd, 0x00, 0x80]);
      expect(await LinkExtractor.fromFile(f.path), isNull);
    });

    test('of several files, the first with a link wins', () async {
      final a = write('a.jpg', 'nothing').path;
      final b = write('b.url', 'URL=https://b.com/x').path;
      final c = write('c.url', 'URL=https://c.com/y').path;
      expect(
        await LinkExtractor.fromFiles([a, b, c]),
        Uri.parse('https://b.com/x'),
      );
      expect(await LinkExtractor.fromFiles([a]), isNull);
      expect(await LinkExtractor.fromFiles(const []), isNull);
    });
  });

  group('the drop target', () {
    Widget host(ShellCubit shell, LinkDropController controller, Key key) =>
        BlocProvider.value(
          value: shell,
          child: LinkDropTarget(
            key: key,
            native: false,
            controller: controller,
            child: const SizedBox(
              width: 400,
              height: 300,
              child: Text('window'),
            ),
          ),
        );

    haulTest(
      'shows an overlay while a drag is over the window, and hides it after',
      (tester) async {
        final shell = ShellCubit();
        final controller = LinkDropController();
        addTearDown(shell.close);
        addTearDown(controller.dispose);
        await pumpHaul(tester, host(shell, controller, const ValueKey('t')));
        double opacity() => tester
            .widget<AnimatedOpacity>(
              find.descendant(
                of: find.byType(LinkDropTarget),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity;
        expect(opacity(), 0);
        expect(find.text('Drop the link to download it'), findsOneWidget);

        controller.enter();
        await tester.pump();
        expect(opacity(), 1);

        controller.leave();
        await tester.pump();
        expect(opacity(), 0);
      },
    );

    haulTest('the overlay does not block clicks until a drag arrives', (
      tester,
    ) async {
      final shell = ShellCubit();
      final controller = LinkDropController();
      addTearDown(shell.close);
      addTearDown(controller.dispose);
      var taps = 0;
      await pumpHaul(
        tester,
        BlocProvider.value(
          value: shell,
          child: LinkDropTarget(
            native: false,
            controller: controller,
            child: HaulButton(label: 'Go', onPressed: () => taps++),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    haulTest('dropping text with a link opens the dialog with it', (
      tester,
    ) async {
      final shell = ShellCubit();
      final controller = LinkDropController();
      addTearDown(shell.close);
      addTearDown(controller.dispose);
      final key = GlobalKey();
      await pumpHaul(tester, host(shell, controller, key));
      final state = key.currentState! as dynamic;
      controller.enter();
      state.dropText('https://a.com/file.zip');
      expect(shell.state.addDialogOpen, isTrue);
      expect(shell.state.addDialogUrl, 'https://a.com/file.zip');
      expect(controller.active, isFalse, reason: 'the overlay goes away');
    });

    haulTest('dropping text with no link does nothing', (tester) async {
      final shell = ShellCubit();
      final controller = LinkDropController();
      addTearDown(shell.close);
      addTearDown(controller.dispose);
      final key = GlobalKey();
      await pumpHaul(tester, host(shell, controller, key));
      (key.currentState! as dynamic).dropText('just some words');
      expect(shell.state.addDialogOpen, isFalse);
    });

    haulTest(
      'dropping a link file opens the dialog, any other file does nothing',
      (tester) async {
        final dir = Directory.systemTemp.createTempSync('drop_w_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final link = File('${dir.path}/page.webloc')..writeAsStringSync(webloc);
        final photo = File('${dir.path}/photo.jpg')..writeAsStringSync('x');

        final shell = ShellCubit();
        final controller = LinkDropController();
        addTearDown(shell.close);
        addTearDown(controller.dispose);
        final key = GlobalKey();
        await pumpHaul(tester, host(shell, controller, key));
        final state = key.currentState! as dynamic;

        await tester.runAsync(
          () => state.dropFiles([photo.path]) as Future<void>,
        );
        expect(shell.state.addDialogOpen, isFalse);

        await tester.runAsync(
          () => state.dropFiles([link.path]) as Future<void>,
        );
        expect(shell.state.addDialogOpen, isTrue);
        expect(
          shell.state.addDialogUrl,
          'https://example.com/files/big.zip?a=1&b=2',
        );
      },
    );
  });

  group('Command-V', () {
    late ShellCubit shell;
    late DownloadsCubit downloads;
    late HaulCommands commands;
    late dynamic deps;

    setUp(() async {
      final t = await makeTestDeps();
      deps = t.deps;
      shell = ShellCubit();
      downloads = DownloadsCubit(t.deps.downloads, t.deps.categories);
      commands = HaulCommands(shell: shell, downloads: downloads);
    });
    tearDown(() async {
      await shell.close();
      await downloads.close();
      await deps.dispose();
    });

    haulTest('opens the Add URL dialog when nothing is being typed into', (
      tester,
    ) async {
      await pumpHaul(tester, const Text('window'));
      commands.paste();
      expect(shell.state.addDialogOpen, isTrue);
    });

    haulTest('pastes into the search box instead when it has focus', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpHaul(
        tester,
        SizedBox(
          width: 300,
          child: HaulTextField(focusNode: focus, hint: 'Search'),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      commands.paste();
      expect(shell.state.addDialogOpen, isFalse);
    });
  });
}
