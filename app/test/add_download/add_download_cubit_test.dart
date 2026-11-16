import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/dependencies.dart';
import 'package:haul/data/categories_repository.dart';
import 'package:haul/data/downloads_dao.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/features/add_download/add_download_cubit.dart';
import 'package:haul/services/network/url_prober.dart';
import 'package:haul/services/system/folder_picker.dart';

import '../support/test_deps.dart';

const mib = 1024 * 1024;

/// A prober the test controls: it answers when told to.
class FakeProber implements UrlProber {
  final calls = <Uri>[];
  final _pending = <Uri, Completer<UrlInfo>>{};
  UrlInfo? answer;
  String? failWith;
  ({String? referrer, String? cookies, String? userAgent})? lastHeaders;

  @override
  Future<UrlInfo> probe(
    Uri url, {
    String? referrer,
    String? cookies,
    String? userAgent,
  }) {
    calls.add(url);
    lastHeaders = (referrer: referrer, cookies: cookies, userAgent: userAgent);
    if (failWith != null) return Future.error(UrlProbeException(failWith!));
    if (answer != null) return Future.value(answer);
    return (_pending[url] = Completer<UrlInfo>()).future;
  }

  void complete(Uri url, UrlInfo info) => _pending[url]!.complete(info);
}

class FakePicker implements FolderPicker {
  String? next;
  String? lastStart;

  @override
  Future<String?> pick({String? startIn}) async {
    lastStart = startIn;
    return next;
  }
}

Future<void> wait([int ms = 80]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late AppDependencies deps;
  late FakeEngine engine;
  late FakeProber prober;
  late FakePicker picker;
  late List<DownloadCategory> categories;
  late AddDownloadCubit cubit;
  var ids = 0;

  AddDownloadCubit make({String url = ''}) => AddDownloadCubit(
    downloads: deps.downloads,
    settings: deps.settings,
    prober: prober,
    picker: picker,
    categories: categories,
    existing: () => existingList,
    fallbackSaveDir: '/fallback',
    rememberFolder: deps.categories.setSaveDir,
    url: url,
    debounce: const Duration(milliseconds: 20),
    newId: () => 'id${ids++}',
  );

  setUp(() async {
    final t = await makeTestDeps(downloadsDir: '/dl');
    deps = t.deps;
    engine = t.engine;
    prober = FakeProber();
    picker = FakePicker();
    categories = await deps.categories.all();
    existingList = [];
    ids = 0;
    cubit = make();
  });
  tearDown(() async {
    await cubit.close();
    await deps.dispose();
  });

  group('parseLink', () {
    test('accepts http and https links with a host', () {
      expect(AddDownloadCubit.parseLink('https://a.com/f.zip'), isNotNull);
      expect(AddDownloadCubit.parseLink('http://a.com'), isNotNull);
      expect(AddDownloadCubit.parseLink('  https://a.com/x  '), isNotNull);
      expect(AddDownloadCubit.parseLink('http://127.0.0.1:8080/a'), isNotNull);
    });

    test('rejects everything else', () {
      for (final bad in [
        '',
        '   ',
        'hello',
        'a.com/file.zip',
        'ftp://a.com/f',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'https://',
        'http:///nohost',
        'data:text/plain,hi',
        'blob:https://a.com/uuid',
      ]) {
        expect(AddDownloadCubit.parseLink(bad), isNull, reason: bad);
      }
    });
  });

  group('the link field', () {
    test('says nothing while empty', () {
      expect(cubit.state.urlError, isNull);
      cubit.setUrl('   ');
      expect(cubit.state.urlError, isNull);
    });

    test('explains what is wrong with a bad link', () {
      cubit.setUrl('not a link');
      expect(cubit.state.urlError, 'That does not look like a link');
      cubit.setUrl('ftp://a.com/f');
      expect(cubit.state.urlError, 'Only http and https links work');
    });

    test('clears the error once the link is good', () {
      cubit.setUrl('nope');
      cubit.setUrl('https://a.com/f.zip');
      expect(cubit.state.urlError, isNull);
    });
  });

  group('probing', () {
    test('waits for a pause in typing, then looks at the link', () async {
      cubit.setUrl('https://a.com/f.zip');
      expect(cubit.state.probe, ProbeStatus.checking);
      expect(prober.calls, isEmpty);
      await wait();
      expect(prober.calls.single, Uri.parse('https://a.com/f.zip'));
    });

    test('only the last link typed is probed', () async {
      cubit.setUrl('https://a.com/a');
      cubit.setUrl('https://a.com/ab');
      cubit.setUrl('https://a.com/abc');
      await wait();
      expect(prober.calls.map((u) => u.path), ['/abc']);
    });

    test('shows the detected name and size', () async {
      prober.answer = const UrlInfo(
        fileName: 'ubuntu.iso',
        size: 4 * 1024 * mib,
        supportsRanges: true,
      );
      cubit.setUrl('https://a.com/download?id=3');
      await wait();
      expect(cubit.state.probe, ProbeStatus.found);
      expect(cubit.state.info!.fileName, 'ubuntu.iso');
      expect(cubit.state.info!.size, 4 * 1024 * mib);
    });

    test('an answer for an old link is ignored', () async {
      final first = Uri.parse('https://a.com/first.zip');
      final second = Uri.parse('https://a.com/second.mp4');
      cubit.setUrl(first.toString());
      await wait();
      cubit.setUrl(second.toString());
      await wait();
      // The first answer turns up late.
      prober.complete(
        first,
        const UrlInfo(fileName: 'first.zip', supportsRanges: true),
      );
      await wait(20);
      expect(cubit.state.info, isNull, reason: 'not the first one');
      prober.complete(
        second,
        const UrlInfo(fileName: 'second.mp4', supportsRanges: true),
      );
      await wait(20);
      expect(cubit.state.info!.fileName, 'second.mp4');
    });

    test('a failure is shown in words', () async {
      prober.failWith = 'The file was not found on the server';
      cubit.setUrl('https://a.com/missing');
      await wait();
      expect(cubit.state.probe, ProbeStatus.failed);
      expect(cubit.state.probeError, 'The file was not found on the server');
    });

    test('a bad link is not probed at all', () async {
      cubit.setUrl('nonsense');
      await wait();
      expect(prober.calls, isEmpty);
      expect(cubit.state.probe, ProbeStatus.idle);
    });

    test('changing the link forgets the old answer', () async {
      prober.answer = const UrlInfo(fileName: 'a.zip', supportsRanges: true);
      cubit.setUrl('https://a.com/a.zip');
      await wait();
      expect(cubit.state.info, isNotNull);
      cubit.setUrl('https://a.com/b.zip');
      expect(cubit.state.info, isNull);
    });

    test('a link given up front is probed straight away', () async {
      prober.answer = const UrlInfo(fileName: 'x.zip', supportsRanges: true);
      final c = make(url: 'https://a.com/x.zip');
      expect(c.state.url, 'https://a.com/x.zip');
      await wait();
      expect(c.state.info!.fileName, 'x.zip');
      await c.close();
    });
  });

  group('category and folder', () {
    DownloadCategory named(String n) =>
        categories.firstWhere((c) => c.name == n);

    test('start in Other, in the Downloads folder', () {
      expect(cubit.state.categoryId, named('Other').id);
      expect(cubit.state.saveDir, '/dl');
    });

    test('the detected name picks the category and its folder', () async {
      prober.answer = const UrlInfo(
        fileName: 'movie.mp4',
        supportsRanges: true,
      );
      cubit.setUrl('https://a.com/dl?id=1');
      await wait();
      expect(cubit.state.categoryId, named('Video').id);
      expect(cubit.state.saveDir, '/dl/Video');
    });

    test('with no detected name, the end of the link is used', () {
      cubit.setUrl('https://a.com/pics/archive.zip');
      expect(cubit.effectiveName, 'archive.zip');
    });

    test(
      'a typed name beats the detected one and re-chooses the category',
      () async {
        prober.answer = const UrlInfo(
          fileName: 'movie.mp4',
          supportsRanges: true,
        );
        cubit.setUrl('https://a.com/dl?id=1');
        await wait();
        cubit.setFileName('notes.pdf');
        expect(cubit.effectiveName, 'notes.pdf');
        expect(cubit.state.categoryId, named('Documents').id);
        expect(cubit.state.saveDir, '/dl/Documents');
      },
    );

    test('a category the person chose is not overruled by the name', () async {
      cubit.setCategory(named('Music').id);
      prober.answer = const UrlInfo(
        fileName: 'movie.mp4',
        supportsRanges: true,
      );
      cubit.setUrl('https://a.com/dl?id=1');
      await wait();
      expect(cubit.state.categoryId, named('Music').id);
      expect(cubit.state.saveDir, '/dl/Music');
    });

    test(
      'choosing a folder sets it and offers to start where it was',
      () async {
        picker.next = '/Volumes/Big/Stuff';
        await cubit.chooseFolder();
        expect(cubit.state.saveDir, '/Volumes/Big/Stuff');
        expect(cubit.state.folderChosen, isTrue);
        expect(picker.lastStart, '/dl');
      },
    );

    test('cancelling the folder chooser changes nothing', () async {
      picker.next = null;
      await cubit.chooseFolder();
      expect(cubit.state.saveDir, '/dl');
      expect(cubit.state.folderChosen, isFalse);
    });

    test('a chosen folder survives the name changing category', () async {
      picker.next = '/Volumes/Big/Stuff';
      await cubit.chooseFolder();
      prober.answer = const UrlInfo(
        fileName: 'movie.mp4',
        supportsRanges: true,
      );
      cubit.setUrl('https://a.com/dl?id=1');
      await wait();
      expect(cubit.state.categoryId, named('Video').id);
      expect(cubit.state.saveDir, '/Volumes/Big/Stuff');
    });

    test('picking a category replaces a folder chosen earlier', () async {
      picker.next = '/Volumes/Big/Stuff';
      await cubit.chooseFolder();
      cubit.setCategory(named('Music').id);
      expect(cubit.state.saveDir, '/dl/Music');
      expect(cubit.state.folderChosen, isFalse);
    });
  });

  group('remember the last folder', () {
    Future<void> addWithChosenFolder() async {
      prober.answer = const UrlInfo(
        fileName: 'movie.mp4',
        supportsRanges: true,
      );
      cubit.setUrl('https://a.com/dl?id=9');
      await wait();
      picker.next = '/elsewhere';
      await cubit.chooseFolder();
      expect(await cubit.submit(), AddOutcome.added);
    }

    Future<String> videoDir() async => (await deps.categories.all())
        .firstWhere((c) => c.name == 'Video')
        .saveDir;

    test('off: the category keeps its folder', () async {
      await addWithChosenFolder();
      expect(await videoDir(), '/dl/Video');
    });

    test('on: a folder chosen by hand becomes the category folder', () async {
      await deps.settings.set(Keys.rememberLastFolderPerCategory, true);
      await addWithChosenFolder();
      expect(await videoDir(), '/elsewhere');
    });
  });

  group('connections', () {
    test('default to the setting, on the nearest choice', () async {
      Future<int> startWith(int setting) async {
        await deps.settings.set(Keys.maxConnections, setting);
        final c = make();
        final n = c.state.connections;
        await c.close();
        return n;
      }

      expect(await startWith(8), 8);
      expect(await startWith(6), 4);
      expect(await startWith(1), 1);
      expect(await startWith(32), 16);
    });

    test('can be changed', () {
      cubit.setConnections(2);
      expect(cubit.state.connections, 2);
    });
  });

  group('Start', () {
    test('an empty link adds nothing and says why', () async {
      expect(await cubit.submit(), AddOutcome.invalid);
      expect(cubit.state.urlError, 'Enter a link to download');
      expect(engine.commands.whereType<AddCommand>(), isEmpty);
    });

    test('a bad link adds nothing and says why', () async {
      cubit.setUrl('ftp://a.com/f.zip');
      expect(await cubit.submit(), AddOutcome.invalid);
      expect(cubit.state.urlError, 'Only http and https links work');
      expect(engine.commands.whereType<AddCommand>(), isEmpty);
      expect(await deps.downloads.downloads(), isEmpty);
    });

    test('a good link starts a download in the chosen folder', () async {
      prober.answer = const UrlInfo(
        fileName: 'movie.mp4',
        supportsRanges: true,
      );
      cubit.setUrl('https://a.com/dl?id=1');
      await wait();
      cubit.setConnections(4);

      expect(await cubit.submit(), AddOutcome.added);

      final cmd = engine.commands.whereType<AddCommand>().single;
      expect(cmd.request.url, Uri.parse('https://a.com/dl?id=1'));
      expect(cmd.request.saveDir, '/dl/Video');
      expect(cmd.request.maxConnections, 4);
      expect(
        cmd.request.fileName,
        isNull,
        reason: 'the engine uses the detected name',
      );
      final stored = (await deps.downloads.downloads()).single;
      expect(
        stored.categoryId,
        categories.firstWhere((c) => c.name == 'Video').id,
      );
      expect(stored.source, 'manual');
    });

    test('a typed file name is passed on', () async {
      cubit.setUrl('https://a.com/x');
      cubit.setFileName('mine.bin');
      await cubit.submit();
      expect(
        engine.commands.whereType<AddCommand>().single.request.fileName,
        'mine.bin',
      );
    });

    test('a link from a browser keeps its source', () async {
      final c = AddDownloadCubit(
        downloads: deps.downloads,
        settings: deps.settings,
        prober: prober,
        picker: picker,
        categories: categories,
        existing: () => const [],
        fallbackSaveDir: '/fallback',
        url: 'https://a.com/x.zip',
        source: 'chrome',
        debounce: const Duration(milliseconds: 20),
        newId: () => 'br1',
      );
      await c.submit();
      expect((await deps.downloads.downloads()).single.source, 'chrome');
      await c.close();
    });

    test('each download gets its own id', () async {
      cubit.setUrl('https://a.com/one');
      await cubit.submit();
      cubit.setUrl('https://a.com/two');
      await cubit.submit();
      final adds = engine.commands.whereType<AddCommand>().toList();
      expect(adds.map((a) => a.request.id).toSet(), hasLength(2));
    });
  });

  group('a link already in the list', () {
    Future<StoredDownload> existingDownload({
      DownloadStatus status = DownloadStatus.paused,
    }) async {
      final request = DownloadRequest(
        id: 'old',
        url: Uri.parse('https://a.com/dup.zip'),
        saveDir: '/d',
      );
      await deps.downloads.add(request);
      engine.emit(
        SnapshotEvent(DownloadSnapshot(request: request, status: status)),
      );
      await wait(150);
      final list = await deps.downloads.downloads();
      existingList = list;
      engine.commands.clear();
      return list.single;
    }

    test('"ask" stops and says which one it matches', () async {
      await deps.settings.set(Keys.duplicateAction, DuplicateAction.ask);
      final old = await existingDownload();
      cubit.setUrl('https://a.com/dup.zip');
      expect(await cubit.submit(), AddOutcome.needsDecision);
      expect(cubit.state.duplicate!.id, old.id);
      expect(engine.commands, isEmpty);
    });

    test('"ask" then add a copy adds it', () async {
      await existingDownload();
      cubit.setUrl('https://a.com/dup.zip');
      await cubit.submit();
      expect(
        await cubit.submit(choice: DuplicateChoice.addCopy),
        AddOutcome.added,
      );
      expect(engine.commands.whereType<AddCommand>(), hasLength(1));
    });

    test('"ask" then resume the existing one resumes it', () async {
      final old = await existingDownload();
      cubit.setUrl('https://a.com/dup.zip');
      await cubit.submit();
      expect(
        await cubit.submit(choice: DuplicateChoice.resumeExisting),
        AddOutcome.resumedExisting,
      );
      expect(engine.commands.whereType<ResumeCommand>().single.id, old.id);
      expect(engine.commands.whereType<AddCommand>(), isEmpty);
    });

    test('"add a numbered copy" adds without asking', () async {
      await deps.settings.set(
        Keys.duplicateAction,
        DuplicateAction.numberedCopy,
      );
      await existingDownload();
      cubit.setUrl('https://a.com/dup.zip');
      expect(await cubit.submit(), AddOutcome.added);
      expect(engine.commands.whereType<AddCommand>(), hasLength(1));
      expect(cubit.state.duplicate, isNull);
    });

    test('"resume the existing one" resumes without asking', () async {
      await deps.settings.set(
        Keys.duplicateAction,
        DuplicateAction.resumeExisting,
      );
      final old = await existingDownload();
      cubit.setUrl('https://a.com/dup.zip');
      expect(await cubit.submit(), AddOutcome.resumedExisting);
      expect(engine.commands.whereType<ResumeCommand>().single.id, old.id);
    });

    test(
      'resuming a finished download does nothing but still counts as handled',
      () async {
        await deps.settings.set(
          Keys.duplicateAction,
          DuplicateAction.resumeExisting,
        );
        await existingDownload(status: DownloadStatus.completed);
        cubit.setUrl('https://a.com/dup.zip');
        expect(await cubit.submit(), AddOutcome.resumedExisting);
        expect(engine.commands, isEmpty);
      },
    );

    test('editing the link clears the duplicate notice', () async {
      await existingDownload();
      cubit.setUrl('https://a.com/dup.zip');
      await cubit.submit();
      expect(cubit.state.duplicate, isNotNull);
      cubit.setUrl('https://a.com/other.zip');
      expect(cubit.state.duplicate, isNull);
    });

    test('a different link is never a duplicate', () async {
      await existingDownload();
      cubit.setUrl('https://a.com/different.zip');
      expect(await cubit.submit(), AddOutcome.added);
    });
  });
}

List<StoredDownload> existingList = [];
