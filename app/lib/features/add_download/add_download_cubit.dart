import 'dart:async';
import 'dart:math';

import 'package:download_engine/download_engine.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/categories_repository.dart';
import '../../data/downloads_dao.dart';
import '../../data/downloads_repository.dart';
import '../../data/setting_keys.dart';
import '../../data/settings_repository.dart';
import '../../services/network/url_prober.dart';
import '../../services/system/folder_picker.dart';
import 'browser_handoff.dart';

enum ProbeStatus { idle, checking, found, failed }

/// What happened when the person pressed Start.
enum AddOutcome {
  /// A new download was started.
  added,

  /// The link was already in the list, and that download was resumed.
  resumedExisting,

  /// The link was already in the list and the person has to choose.
  needsDecision,

  /// The link is not usable. The dialog shows why.
  invalid,
}

/// How to treat a link that is already in the list, when asked.
enum DuplicateChoice { addCopy, resumeExisting }

/// The connection counts on offer.
const connectionChoices = [1, 2, 4, 8, 16];

class AddDownloadState extends Equatable {
  const AddDownloadState({
    this.url = '',
    this.urlError,
    this.probe = ProbeStatus.idle,
    this.info,
    this.probeError,
    this.fileName = '',
    this.categoryId,
    this.categoryChosen = false,
    this.saveDir,
    this.folderChosen = false,
    this.connections = 8,
    this.duplicate,
  });

  /// What was typed, untouched.
  final String url;

  /// Shown under the field, in words.
  final String? urlError;
  final ProbeStatus probe;
  final UrlInfo? info;
  final String? probeError;

  /// Only what the person typed; empty means "use the detected name".
  final String fileName;
  final int? categoryId;

  /// True once the person picked a category themselves, so the detected name
  /// stops choosing for them.
  final bool categoryChosen;
  final String? saveDir;
  final bool folderChosen;
  final int connections;

  /// Set when Start found this link already in the list.
  final StoredDownload? duplicate;

  AddDownloadState copyWith({
    String? url,
    String? urlError,
    bool clearUrlError = false,
    ProbeStatus? probe,
    UrlInfo? info,
    bool clearInfo = false,
    String? probeError,
    bool clearProbeError = false,
    String? fileName,
    int? categoryId,
    bool? categoryChosen,
    String? saveDir,
    bool? folderChosen,
    int? connections,
    StoredDownload? duplicate,
    bool clearDuplicate = false,
  }) => AddDownloadState(
    url: url ?? this.url,
    urlError: clearUrlError ? null : (urlError ?? this.urlError),
    probe: probe ?? this.probe,
    info: clearInfo ? null : (info ?? this.info),
    probeError: clearProbeError ? null : (probeError ?? this.probeError),
    fileName: fileName ?? this.fileName,
    categoryId: categoryId ?? this.categoryId,
    categoryChosen: categoryChosen ?? this.categoryChosen,
    saveDir: saveDir ?? this.saveDir,
    folderChosen: folderChosen ?? this.folderChosen,
    connections: connections ?? this.connections,
    duplicate: clearDuplicate ? null : (duplicate ?? this.duplicate),
  );

  @override
  List<Object?> get props => [
    url,
    urlError,
    probe,
    info?.fileName,
    info?.size,
    probeError,
    fileName,
    categoryId,
    categoryChosen,
    saveDir,
    folderChosen,
    connections,
    duplicate?.id,
  ];
}

/// The logic of the Add URL dialog, kept apart from how it looks.
class AddDownloadCubit extends Cubit<AddDownloadState> {
  AddDownloadCubit({
    required DownloadsRepository downloads,
    required SettingsRepository settings,
    required UrlProber prober,
    required FolderPicker picker,
    required List<DownloadCategory> categories,
    required List<StoredDownload> Function() existing,
    required String fallbackSaveDir,
    Future<void> Function(int categoryId, String saveDir)? rememberFolder,
    String url = '',
    this.handoff,
    String source = 'manual',
    this.debounce = const Duration(milliseconds: 400),
    String Function()? newId,
  }) : _downloads = downloads,
       _settings = settings,
       _prober = prober,
       _picker = picker,
       _categories = categories,
       _existing = existing,
       _fallbackSaveDir = fallbackSaveDir,
       _rememberFolder = rememberFolder,
       _newId = handoff != null ? (() => handoff.id) : (newId ?? _randomId),
       source = handoff?.payload.source ?? source,
       super(const AddDownloadState()) {
    final other = _categoryFor('');
    emit(
      AddDownloadState(
        categoryId: other?.id,
        saveDir: other?.saveDir ?? fallbackSaveDir,
        connections: _nearestChoice(_settings.get(Keys.maxConnections)),
      ),
    );
    final h = handoff;
    if (h != null) {
      // What the browser knew: the name it was going to save under.
      final name = h.payload.fileName;
      if (name != null && name.isNotEmpty) setFileName(name);
      setUrl(h.payload.url.toString());
    } else if (url.isNotEmpty) {
      setUrl(url);
    }
  }

  final DownloadsRepository _downloads;
  final SettingsRepository _settings;
  final UrlProber _prober;
  final FolderPicker _picker;
  final List<DownloadCategory> _categories;
  final List<StoredDownload> Function() _existing;
  final String _fallbackSaveDir;
  final Future<void> Function(int categoryId, String saveDir)? _rememberFolder;
  final String Function() _newId;

  /// `manual`, or the browser a link came from.
  final String source;

  /// Set when the browser extension sent this download.
  final BrowserHandoff? handoff;
  final Duration debounce;

  Timer? _timer;
  int _probeSeq = 0;

  static final _rng = Random();
  static String _randomId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(1 << 32).toRadixString(36)}';

  static int _nearestChoice(int wanted) {
    var best = connectionChoices.first;
    for (final c in connectionChoices) {
      if (c <= wanted) best = c;
    }
    return best;
  }

  // -- the link ------------------------------------------------------------

  /// A usable link: `http` or `https`, with a host.
  static Uri? parseLink(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  void setUrl(String input) {
    _timer?.cancel();
    _probeSeq++;
    final uri = parseLink(input);
    emit(
      state.copyWith(
        url: input,
        clearDuplicate: true,
        clearInfo: true,
        clearProbeError: true,
        probe: uri == null ? ProbeStatus.idle : ProbeStatus.checking,
        // Say what is wrong once there is something to be wrong about.
        urlError: input.trim().isEmpty || uri != null ? null : _whyNot(input),
        clearUrlError: input.trim().isEmpty || uri != null,
      ),
    );
    if (uri != null) {
      final seq = _probeSeq;
      _timer = Timer(debounce, () => _runProbe(uri, seq));
    }
  }

  static String _whyNot(String input) {
    final text = input.trim();
    final uri = Uri.tryParse(text);
    if (uri != null &&
        uri.hasScheme &&
        uri.scheme != 'http' &&
        uri.scheme != 'https') {
      return 'Only http and https links work';
    }
    return 'That does not look like a link';
  }

  Future<void> _runProbe(Uri uri, int seq) async {
    try {
      final p = handoff?.payload;
      final info = await _prober.probe(
        uri,
        referrer: p?.referrer,
        cookies: p?.cookies,
        userAgent: p?.userAgent,
      );
      if (seq != _probeSeq || isClosed) return; // a newer link replaced it
      emit(state.copyWith(probe: ProbeStatus.found, info: info));
      _autoCategory();
    } on UrlProbeException catch (e) {
      if (seq != _probeSeq || isClosed) return;
      emit(state.copyWith(probe: ProbeStatus.failed, probeError: e.message));
    }
  }

  // -- name, category, folder, connections ---------------------------------

  /// The name the download will get: what was typed, else what the server
  /// suggested, else the end of the link.
  String get effectiveName {
    if (state.fileName.trim().isNotEmpty) return state.fileName.trim();
    final detected = state.info?.fileName;
    if (detected != null && detected.isNotEmpty) return detected;
    final uri = parseLink(state.url);
    final segments = uri?.pathSegments.where((s) => s.isNotEmpty);
    return segments == null || segments.isEmpty ? '' : segments.last;
  }

  DownloadCategory? _categoryFor(String name) {
    if (_categories.isEmpty) return null;
    final ext = CategoriesRepository.extensionOf(name);
    if (ext != null) {
      for (final c in _categories) {
        if (c.extensions.contains(ext)) return c;
      }
    }
    return _categories.firstWhere(
      (c) => c.name == otherCategoryName,
      orElse: () => _categories.last,
    );
  }

  /// Chooses the category from the name, unless the person already did.
  void _autoCategory() {
    if (state.categoryChosen) return;
    final c = _categoryFor(effectiveName);
    if (c == null) return;
    emit(
      state.copyWith(
        categoryId: c.id,
        saveDir: state.folderChosen ? state.saveDir : c.saveDir,
      ),
    );
  }

  void setFileName(String name) {
    emit(state.copyWith(fileName: name));
    _autoCategory();
  }

  /// Picking a category also picks its folder, replacing a folder chosen
  /// earlier.
  void setCategory(int id) {
    final c = _categories.firstWhere((c) => c.id == id);
    emit(
      state.copyWith(
        categoryId: id,
        categoryChosen: true,
        saveDir: c.saveDir,
        folderChosen: false,
      ),
    );
  }

  Future<void> chooseFolder() async {
    final path = await _picker.pick(startIn: state.saveDir);
    if (path == null || isClosed) return;
    emit(state.copyWith(saveDir: path, folderChosen: true));
  }

  void setConnections(int n) => emit(state.copyWith(connections: n));

  // -- start ---------------------------------------------------------------

  /// The existing download with the same link, if any.
  StoredDownload? findDuplicate(Uri url) {
    final wanted = url.toString();
    for (final d in _existing()) {
      if (d.snapshot.request.url.toString() == wanted) return d;
    }
    return null;
  }

  /// Starts the download. If the link is already in the list, what happens
  /// follows the "when a URL is already in the list" setting, unless
  /// [choice] says otherwise.
  Future<AddOutcome> submit({DuplicateChoice? choice}) async {
    final uri = parseLink(state.url);
    if (uri == null) {
      emit(
        state.copyWith(
          urlError: state.url.trim().isEmpty
              ? 'Enter a link to download'
              : _whyNot(state.url),
        ),
      );
      return AddOutcome.invalid;
    }

    final dup = findDuplicate(uri);
    if (dup != null) {
      final action =
          choice ??
          switch (_settings.get(Keys.duplicateAction)) {
            DuplicateAction.ask => null,
            DuplicateAction.numberedCopy => DuplicateChoice.addCopy,
            DuplicateAction.resumeExisting => DuplicateChoice.resumeExisting,
          };
      if (action == null) {
        emit(state.copyWith(duplicate: dup));
        return AddOutcome.needsDecision;
      }
      if (action == DuplicateChoice.resumeExisting) {
        if (dup.snapshot.status.canResume) _downloads.resume(dup.id);
        return AddOutcome.resumedExisting;
      }
      // addCopy: fall through. The engine numbers the file name if needed.
    }

    final typed = state.fileName.trim();
    final request = DownloadRequest(
      id: _newId(),
      url: uri,
      saveDir: state.saveDir ?? _fallbackSaveDir,
      fileName: typed.isEmpty ? null : typed,
      // The browser's own headers go with the download, so a file behind a
      // login still works.
      referrer: handoff?.payload.referrer,
      userAgent: handoff?.payload.userAgent,
      cookies: handoff?.payload.cookies,
      maxConnections: state.connections,
    );
    await _downloads.add(request, source: source, categoryId: state.categoryId);
    // "Remember the last folder per category": a folder chosen by hand becomes
    // that category's folder for next time.
    final remember = _rememberFolder;
    final categoryId = state.categoryId;
    if (remember != null &&
        state.folderChosen &&
        categoryId != null &&
        _settings.get(Keys.rememberLastFolderPerCategory)) {
      await remember(categoryId, request.saveDir);
    }
    return AddOutcome.added;
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
