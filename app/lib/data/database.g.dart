// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, DownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finalUrlMeta = const VerificationMeta(
    'finalUrl',
  );
  @override
  late final GeneratedColumn<String> finalUrl = GeneratedColumn<String>(
    'final_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saveDirMeta = const VerificationMeta(
    'saveDir',
  );
  @override
  late final GeneratedColumn<String> saveDir = GeneratedColumn<String>(
    'save_dir',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supportsRangesMeta = const VerificationMeta(
    'supportsRanges',
  );
  @override
  late final GeneratedColumn<bool> supportsRanges = GeneratedColumn<bool>(
    'supports_ranges',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_ranges" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _resumableMeta = const VerificationMeta(
    'resumable',
  );
  @override
  late final GeneratedColumn<bool> resumable = GeneratedColumn<bool>(
    'resumable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("resumable" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<String> lastModified = GeneratedColumn<String>(
    'last_modified',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestHeadersMeta = const VerificationMeta(
    'requestHeaders',
  );
  @override
  late final GeneratedColumn<String> requestHeaders = GeneratedColumn<String>(
    'request_headers',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _maxConnectionsMeta = const VerificationMeta(
    'maxConnections',
  );
  @override
  late final GeneratedColumn<int> maxConnections = GeneratedColumn<int>(
    'max_connections',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    url,
    finalUrl,
    fileName,
    saveDir,
    totalBytes,
    downloadedBytes,
    status,
    supportsRanges,
    resumable,
    etag,
    lastModified,
    contentType,
    requestHeaders,
    maxConnections,
    categoryId,
    source,
    errorCode,
    errorMessage,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('final_url')) {
      context.handle(
        _finalUrlMeta,
        finalUrl.isAcceptableOrUnknown(data['final_url']!, _finalUrlMeta),
      );
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('save_dir')) {
      context.handle(
        _saveDirMeta,
        saveDir.isAcceptableOrUnknown(data['save_dir']!, _saveDirMeta),
      );
    } else if (isInserting) {
      context.missing(_saveDirMeta);
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('supports_ranges')) {
      context.handle(
        _supportsRangesMeta,
        supportsRanges.isAcceptableOrUnknown(
          data['supports_ranges']!,
          _supportsRangesMeta,
        ),
      );
    }
    if (data.containsKey('resumable')) {
      context.handle(
        _resumableMeta,
        resumable.isAcceptableOrUnknown(data['resumable']!, _resumableMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    }
    if (data.containsKey('request_headers')) {
      context.handle(
        _requestHeadersMeta,
        requestHeaders.isAcceptableOrUnknown(
          data['request_headers']!,
          _requestHeadersMeta,
        ),
      );
    }
    if (data.containsKey('max_connections')) {
      context.handle(
        _maxConnectionsMeta,
        maxConnections.isAcceptableOrUnknown(
          data['max_connections']!,
          _maxConnectionsMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      finalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_url'],
      ),
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      ),
      saveDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}save_dir'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      supportsRanges: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_ranges'],
      )!,
      resumable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}resumable'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified'],
      ),
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      ),
      requestHeaders: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_headers'],
      )!,
      maxConnections: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_connections'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class DownloadRow extends DataClass implements Insertable<DownloadRow> {
  final String id;
  final String url;
  final String? finalUrl;
  final String? fileName;
  final String saveDir;
  final int? totalBytes;
  final int downloadedBytes;
  final String status;
  final bool supportsRanges;
  final bool resumable;
  final String? etag;
  final String? lastModified;

  /// Content-Type from the probe. The engine snapshot carries it and the
  /// UI uses it for the file icon.
  final String? contentType;

  /// JSON: referrer, user agent, cookies and the file name the caller asked for.
  final String requestHeaders;
  final int maxConnections;

  /// Which category chose the save folder. Null for downloads that predate
  /// categories or were saved somewhere by hand.
  final int? categoryId;

  /// `manual`, `chrome` or `firefox`.
  final String source;
  final String? errorCode;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  const DownloadRow({
    required this.id,
    required this.url,
    this.finalUrl,
    this.fileName,
    required this.saveDir,
    this.totalBytes,
    required this.downloadedBytes,
    required this.status,
    required this.supportsRanges,
    required this.resumable,
    this.etag,
    this.lastModified,
    this.contentType,
    required this.requestHeaders,
    required this.maxConnections,
    this.categoryId,
    required this.source,
    this.errorCode,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || finalUrl != null) {
      map['final_url'] = Variable<String>(finalUrl);
    }
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    map['save_dir'] = Variable<String>(saveDir);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    map['status'] = Variable<String>(status);
    map['supports_ranges'] = Variable<bool>(supportsRanges);
    map['resumable'] = Variable<bool>(resumable);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<String>(lastModified);
    }
    if (!nullToAbsent || contentType != null) {
      map['content_type'] = Variable<String>(contentType);
    }
    map['request_headers'] = Variable<String>(requestHeaders);
    map['max_connections'] = Variable<int>(maxConnections);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      id: Value(id),
      url: Value(url),
      finalUrl: finalUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(finalUrl),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      saveDir: Value(saveDir),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      downloadedBytes: Value(downloadedBytes),
      status: Value(status),
      supportsRanges: Value(supportsRanges),
      resumable: Value(resumable),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
      contentType: contentType == null && nullToAbsent
          ? const Value.absent()
          : Value(contentType),
      requestHeaders: Value(requestHeaders),
      maxConnections: Value(maxConnections),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      source: Value(source),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRow(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      finalUrl: serializer.fromJson<String?>(json['finalUrl']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      saveDir: serializer.fromJson<String>(json['saveDir']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      status: serializer.fromJson<String>(json['status']),
      supportsRanges: serializer.fromJson<bool>(json['supportsRanges']),
      resumable: serializer.fromJson<bool>(json['resumable']),
      etag: serializer.fromJson<String?>(json['etag']),
      lastModified: serializer.fromJson<String?>(json['lastModified']),
      contentType: serializer.fromJson<String?>(json['contentType']),
      requestHeaders: serializer.fromJson<String>(json['requestHeaders']),
      maxConnections: serializer.fromJson<int>(json['maxConnections']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      source: serializer.fromJson<String>(json['source']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String>(url),
      'finalUrl': serializer.toJson<String?>(finalUrl),
      'fileName': serializer.toJson<String?>(fileName),
      'saveDir': serializer.toJson<String>(saveDir),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'status': serializer.toJson<String>(status),
      'supportsRanges': serializer.toJson<bool>(supportsRanges),
      'resumable': serializer.toJson<bool>(resumable),
      'etag': serializer.toJson<String?>(etag),
      'lastModified': serializer.toJson<String?>(lastModified),
      'contentType': serializer.toJson<String?>(contentType),
      'requestHeaders': serializer.toJson<String>(requestHeaders),
      'maxConnections': serializer.toJson<int>(maxConnections),
      'categoryId': serializer.toJson<int?>(categoryId),
      'source': serializer.toJson<String>(source),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadRow copyWith({
    String? id,
    String? url,
    Value<String?> finalUrl = const Value.absent(),
    Value<String?> fileName = const Value.absent(),
    String? saveDir,
    Value<int?> totalBytes = const Value.absent(),
    int? downloadedBytes,
    String? status,
    bool? supportsRanges,
    bool? resumable,
    Value<String?> etag = const Value.absent(),
    Value<String?> lastModified = const Value.absent(),
    Value<String?> contentType = const Value.absent(),
    String? requestHeaders,
    int? maxConnections,
    Value<int?> categoryId = const Value.absent(),
    String? source,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadRow(
    id: id ?? this.id,
    url: url ?? this.url,
    finalUrl: finalUrl.present ? finalUrl.value : this.finalUrl,
    fileName: fileName.present ? fileName.value : this.fileName,
    saveDir: saveDir ?? this.saveDir,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    status: status ?? this.status,
    supportsRanges: supportsRanges ?? this.supportsRanges,
    resumable: resumable ?? this.resumable,
    etag: etag.present ? etag.value : this.etag,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    contentType: contentType.present ? contentType.value : this.contentType,
    requestHeaders: requestHeaders ?? this.requestHeaders,
    maxConnections: maxConnections ?? this.maxConnections,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    source: source ?? this.source,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadRow copyWithCompanion(DownloadsCompanion data) {
    return DownloadRow(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      finalUrl: data.finalUrl.present ? data.finalUrl.value : this.finalUrl,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      saveDir: data.saveDir.present ? data.saveDir.value : this.saveDir,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      status: data.status.present ? data.status.value : this.status,
      supportsRanges: data.supportsRanges.present
          ? data.supportsRanges.value
          : this.supportsRanges,
      resumable: data.resumable.present ? data.resumable.value : this.resumable,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      requestHeaders: data.requestHeaders.present
          ? data.requestHeaders.value
          : this.requestHeaders,
      maxConnections: data.maxConnections.present
          ? data.maxConnections.value
          : this.maxConnections,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      source: data.source.present ? data.source.value : this.source,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRow(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('finalUrl: $finalUrl, ')
          ..write('fileName: $fileName, ')
          ..write('saveDir: $saveDir, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('status: $status, ')
          ..write('supportsRanges: $supportsRanges, ')
          ..write('resumable: $resumable, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('contentType: $contentType, ')
          ..write('requestHeaders: $requestHeaders, ')
          ..write('maxConnections: $maxConnections, ')
          ..write('categoryId: $categoryId, ')
          ..write('source: $source, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    url,
    finalUrl,
    fileName,
    saveDir,
    totalBytes,
    downloadedBytes,
    status,
    supportsRanges,
    resumable,
    etag,
    lastModified,
    contentType,
    requestHeaders,
    maxConnections,
    categoryId,
    source,
    errorCode,
    errorMessage,
    createdAt,
    completedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRow &&
          other.id == this.id &&
          other.url == this.url &&
          other.finalUrl == this.finalUrl &&
          other.fileName == this.fileName &&
          other.saveDir == this.saveDir &&
          other.totalBytes == this.totalBytes &&
          other.downloadedBytes == this.downloadedBytes &&
          other.status == this.status &&
          other.supportsRanges == this.supportsRanges &&
          other.resumable == this.resumable &&
          other.etag == this.etag &&
          other.lastModified == this.lastModified &&
          other.contentType == this.contentType &&
          other.requestHeaders == this.requestHeaders &&
          other.maxConnections == this.maxConnections &&
          other.categoryId == this.categoryId &&
          other.source == this.source &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class DownloadsCompanion extends UpdateCompanion<DownloadRow> {
  final Value<String> id;
  final Value<String> url;
  final Value<String?> finalUrl;
  final Value<String?> fileName;
  final Value<String> saveDir;
  final Value<int?> totalBytes;
  final Value<int> downloadedBytes;
  final Value<String> status;
  final Value<bool> supportsRanges;
  final Value<bool> resumable;
  final Value<String?> etag;
  final Value<String?> lastModified;
  final Value<String?> contentType;
  final Value<String> requestHeaders;
  final Value<int> maxConnections;
  final Value<int?> categoryId;
  final Value<String> source;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.finalUrl = const Value.absent(),
    this.fileName = const Value.absent(),
    this.saveDir = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.status = const Value.absent(),
    this.supportsRanges = const Value.absent(),
    this.resumable = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.contentType = const Value.absent(),
    this.requestHeaders = const Value.absent(),
    this.maxConnections = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.source = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String id,
    required String url,
    this.finalUrl = const Value.absent(),
    this.fileName = const Value.absent(),
    required String saveDir,
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    required String status,
    this.supportsRanges = const Value.absent(),
    this.resumable = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.contentType = const Value.absent(),
    this.requestHeaders = const Value.absent(),
    this.maxConnections = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.source = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url),
       saveDir = Value(saveDir),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<DownloadRow> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<String>? finalUrl,
    Expression<String>? fileName,
    Expression<String>? saveDir,
    Expression<int>? totalBytes,
    Expression<int>? downloadedBytes,
    Expression<String>? status,
    Expression<bool>? supportsRanges,
    Expression<bool>? resumable,
    Expression<String>? etag,
    Expression<String>? lastModified,
    Expression<String>? contentType,
    Expression<String>? requestHeaders,
    Expression<int>? maxConnections,
    Expression<int>? categoryId,
    Expression<String>? source,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (finalUrl != null) 'final_url': finalUrl,
      if (fileName != null) 'file_name': fileName,
      if (saveDir != null) 'save_dir': saveDir,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (status != null) 'status': status,
      if (supportsRanges != null) 'supports_ranges': supportsRanges,
      if (resumable != null) 'resumable': resumable,
      if (etag != null) 'etag': etag,
      if (lastModified != null) 'last_modified': lastModified,
      if (contentType != null) 'content_type': contentType,
      if (requestHeaders != null) 'request_headers': requestHeaders,
      if (maxConnections != null) 'max_connections': maxConnections,
      if (categoryId != null) 'category_id': categoryId,
      if (source != null) 'source': source,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith({
    Value<String>? id,
    Value<String>? url,
    Value<String?>? finalUrl,
    Value<String?>? fileName,
    Value<String>? saveDir,
    Value<int?>? totalBytes,
    Value<int>? downloadedBytes,
    Value<String>? status,
    Value<bool>? supportsRanges,
    Value<bool>? resumable,
    Value<String?>? etag,
    Value<String?>? lastModified,
    Value<String?>? contentType,
    Value<String>? requestHeaders,
    Value<int>? maxConnections,
    Value<int?>? categoryId,
    Value<String>? source,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return DownloadsCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      finalUrl: finalUrl ?? this.finalUrl,
      fileName: fileName ?? this.fileName,
      saveDir: saveDir ?? this.saveDir,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      supportsRanges: supportsRanges ?? this.supportsRanges,
      resumable: resumable ?? this.resumable,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      contentType: contentType ?? this.contentType,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      maxConnections: maxConnections ?? this.maxConnections,
      categoryId: categoryId ?? this.categoryId,
      source: source ?? this.source,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (finalUrl.present) {
      map['final_url'] = Variable<String>(finalUrl.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (saveDir.present) {
      map['save_dir'] = Variable<String>(saveDir.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (supportsRanges.present) {
      map['supports_ranges'] = Variable<bool>(supportsRanges.value);
    }
    if (resumable.present) {
      map['resumable'] = Variable<bool>(resumable.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<String>(lastModified.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (requestHeaders.present) {
      map['request_headers'] = Variable<String>(requestHeaders.value);
    }
    if (maxConnections.present) {
      map['max_connections'] = Variable<int>(maxConnections.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('finalUrl: $finalUrl, ')
          ..write('fileName: $fileName, ')
          ..write('saveDir: $saveDir, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('status: $status, ')
          ..write('supportsRanges: $supportsRanges, ')
          ..write('resumable: $resumable, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('contentType: $contentType, ')
          ..write('requestHeaders: $requestHeaders, ')
          ..write('maxConnections: $maxConnections, ')
          ..write('categoryId: $categoryId, ')
          ..write('source: $source, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SegmentsTable extends Segments
    with TableInfo<$SegmentsTable, SegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _downloadIdMeta = const VerificationMeta(
    'downloadId',
  );
  @override
  late final GeneratedColumn<String> downloadId = GeneratedColumn<String>(
    'download_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES downloads (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _segmentIndexMeta = const VerificationMeta(
    'segmentIndex',
  );
  @override
  late final GeneratedColumn<int> segmentIndex = GeneratedColumn<int>(
    'segment_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    downloadId,
    segmentIndex,
    startOffset,
    endOffset,
    downloadedBytes,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<SegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('download_id')) {
      context.handle(
        _downloadIdMeta,
        downloadId.isAcceptableOrUnknown(data['download_id']!, _downloadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_downloadIdMeta);
    }
    if (data.containsKey('segment_index')) {
      context.handle(
        _segmentIndexMeta,
        segmentIndex.isAcceptableOrUnknown(
          data['segment_index']!,
          _segmentIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_segmentIndexMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {downloadId, segmentIndex},
  ];
  @override
  SegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SegmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      downloadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_id'],
      )!,
      segmentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_index'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      )!,
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      )!,
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $SegmentsTable createAlias(String alias) {
    return $SegmentsTable(attachedDatabase, alias);
  }
}

class SegmentRow extends DataClass implements Insertable<SegmentRow> {
  final int id;
  final String downloadId;

  /// The engine's own id for the segment, unique within one download.
  final int segmentIndex;
  final int startOffset;
  final int endOffset;
  final int downloadedBytes;
  final String status;
  const SegmentRow({
    required this.id,
    required this.downloadId,
    required this.segmentIndex,
    required this.startOffset,
    required this.endOffset,
    required this.downloadedBytes,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['download_id'] = Variable<String>(downloadId);
    map['segment_index'] = Variable<int>(segmentIndex);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    map['status'] = Variable<String>(status);
    return map;
  }

  SegmentsCompanion toCompanion(bool nullToAbsent) {
    return SegmentsCompanion(
      id: Value(id),
      downloadId: Value(downloadId),
      segmentIndex: Value(segmentIndex),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      downloadedBytes: Value(downloadedBytes),
      status: Value(status),
    );
  }

  factory SegmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SegmentRow(
      id: serializer.fromJson<int>(json['id']),
      downloadId: serializer.fromJson<String>(json['downloadId']),
      segmentIndex: serializer.fromJson<int>(json['segmentIndex']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'downloadId': serializer.toJson<String>(downloadId),
      'segmentIndex': serializer.toJson<int>(segmentIndex),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'status': serializer.toJson<String>(status),
    };
  }

  SegmentRow copyWith({
    int? id,
    String? downloadId,
    int? segmentIndex,
    int? startOffset,
    int? endOffset,
    int? downloadedBytes,
    String? status,
  }) => SegmentRow(
    id: id ?? this.id,
    downloadId: downloadId ?? this.downloadId,
    segmentIndex: segmentIndex ?? this.segmentIndex,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    status: status ?? this.status,
  );
  SegmentRow copyWithCompanion(SegmentsCompanion data) {
    return SegmentRow(
      id: data.id.present ? data.id.value : this.id,
      downloadId: data.downloadId.present
          ? data.downloadId.value
          : this.downloadId,
      segmentIndex: data.segmentIndex.present
          ? data.segmentIndex.value
          : this.segmentIndex,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SegmentRow(')
          ..write('id: $id, ')
          ..write('downloadId: $downloadId, ')
          ..write('segmentIndex: $segmentIndex, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    downloadId,
    segmentIndex,
    startOffset,
    endOffset,
    downloadedBytes,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SegmentRow &&
          other.id == this.id &&
          other.downloadId == this.downloadId &&
          other.segmentIndex == this.segmentIndex &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.downloadedBytes == this.downloadedBytes &&
          other.status == this.status);
}

class SegmentsCompanion extends UpdateCompanion<SegmentRow> {
  final Value<int> id;
  final Value<String> downloadId;
  final Value<int> segmentIndex;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<int> downloadedBytes;
  final Value<String> status;
  const SegmentsCompanion({
    this.id = const Value.absent(),
    this.downloadId = const Value.absent(),
    this.segmentIndex = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.status = const Value.absent(),
  });
  SegmentsCompanion.insert({
    this.id = const Value.absent(),
    required String downloadId,
    required int segmentIndex,
    required int startOffset,
    required int endOffset,
    this.downloadedBytes = const Value.absent(),
    required String status,
  }) : downloadId = Value(downloadId),
       segmentIndex = Value(segmentIndex),
       startOffset = Value(startOffset),
       endOffset = Value(endOffset),
       status = Value(status);
  static Insertable<SegmentRow> custom({
    Expression<int>? id,
    Expression<String>? downloadId,
    Expression<int>? segmentIndex,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<int>? downloadedBytes,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (downloadId != null) 'download_id': downloadId,
      if (segmentIndex != null) 'segment_index': segmentIndex,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (status != null) 'status': status,
    });
  }

  SegmentsCompanion copyWith({
    Value<int>? id,
    Value<String>? downloadId,
    Value<int>? segmentIndex,
    Value<int>? startOffset,
    Value<int>? endOffset,
    Value<int>? downloadedBytes,
    Value<String>? status,
  }) {
    return SegmentsCompanion(
      id: id ?? this.id,
      downloadId: downloadId ?? this.downloadId,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (downloadId.present) {
      map['download_id'] = Variable<String>(downloadId.value);
    }
    if (segmentIndex.present) {
      map['segment_index'] = Variable<int>(segmentIndex.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SegmentsCompanion(')
          ..write('id: $id, ')
          ..write('downloadId: $downloadId, ')
          ..write('segmentIndex: $segmentIndex, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _extensionsMeta = const VerificationMeta(
    'extensions',
  );
  @override
  late final GeneratedColumn<String> extensions = GeneratedColumn<String>(
    'extensions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _saveDirMeta = const VerificationMeta(
    'saveDir',
  );
  @override
  late final GeneratedColumn<String> saveDir = GeneratedColumn<String>(
    'save_dir',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _builtInMeta = const VerificationMeta(
    'builtIn',
  );
  @override
  late final GeneratedColumn<bool> builtIn = GeneratedColumn<bool>(
    'built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    extensions,
    saveDir,
    sortOrder,
    builtIn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('extensions')) {
      context.handle(
        _extensionsMeta,
        extensions.isAcceptableOrUnknown(data['extensions']!, _extensionsMeta),
      );
    }
    if (data.containsKey('save_dir')) {
      context.handle(
        _saveDirMeta,
        saveDir.isAcceptableOrUnknown(data['save_dir']!, _saveDirMeta),
      );
    } else if (isInserting) {
      context.missing(_saveDirMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('built_in')) {
      context.handle(
        _builtInMeta,
        builtIn.isAcceptableOrUnknown(data['built_in']!, _builtInMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      extensions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extensions'],
      )!,
      saveDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}save_dir'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      builtIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}built_in'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final int id;
  final String name;

  /// JSON list of lower-case extensions without the dot.
  final String extensions;
  final String saveDir;
  final int sortOrder;
  final bool builtIn;
  const CategoryRow({
    required this.id,
    required this.name,
    required this.extensions,
    required this.saveDir,
    required this.sortOrder,
    required this.builtIn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['extensions'] = Variable<String>(extensions);
    map['save_dir'] = Variable<String>(saveDir);
    map['sort_order'] = Variable<int>(sortOrder);
    map['built_in'] = Variable<bool>(builtIn);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      extensions: Value(extensions),
      saveDir: Value(saveDir),
      sortOrder: Value(sortOrder),
      builtIn: Value(builtIn),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      extensions: serializer.fromJson<String>(json['extensions']),
      saveDir: serializer.fromJson<String>(json['saveDir']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      builtIn: serializer.fromJson<bool>(json['builtIn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'extensions': serializer.toJson<String>(extensions),
      'saveDir': serializer.toJson<String>(saveDir),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'builtIn': serializer.toJson<bool>(builtIn),
    };
  }

  CategoryRow copyWith({
    int? id,
    String? name,
    String? extensions,
    String? saveDir,
    int? sortOrder,
    bool? builtIn,
  }) => CategoryRow(
    id: id ?? this.id,
    name: name ?? this.name,
    extensions: extensions ?? this.extensions,
    saveDir: saveDir ?? this.saveDir,
    sortOrder: sortOrder ?? this.sortOrder,
    builtIn: builtIn ?? this.builtIn,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      extensions: data.extensions.present
          ? data.extensions.value
          : this.extensions,
      saveDir: data.saveDir.present ? data.saveDir.value : this.saveDir,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      builtIn: data.builtIn.present ? data.builtIn.value : this.builtIn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('extensions: $extensions, ')
          ..write('saveDir: $saveDir, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('builtIn: $builtIn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, extensions, saveDir, sortOrder, builtIn);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.extensions == this.extensions &&
          other.saveDir == this.saveDir &&
          other.sortOrder == this.sortOrder &&
          other.builtIn == this.builtIn);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> extensions;
  final Value<String> saveDir;
  final Value<int> sortOrder;
  final Value<bool> builtIn;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.extensions = const Value.absent(),
    this.saveDir = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.builtIn = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.extensions = const Value.absent(),
    required String saveDir,
    this.sortOrder = const Value.absent(),
    this.builtIn = const Value.absent(),
  }) : name = Value(name),
       saveDir = Value(saveDir);
  static Insertable<CategoryRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? extensions,
    Expression<String>? saveDir,
    Expression<int>? sortOrder,
    Expression<bool>? builtIn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (extensions != null) 'extensions': extensions,
      if (saveDir != null) 'save_dir': saveDir,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (builtIn != null) 'built_in': builtIn,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? extensions,
    Value<String>? saveDir,
    Value<int>? sortOrder,
    Value<bool>? builtIn,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      extensions: extensions ?? this.extensions,
      saveDir: saveDir ?? this.saveDir,
      sortOrder: sortOrder ?? this.sortOrder,
      builtIn: builtIn ?? this.builtIn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (extensions.present) {
      map['extensions'] = Variable<String>(extensions.value);
    }
    if (saveDir.present) {
      map['save_dir'] = Variable<String>(saveDir.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (builtIn.present) {
      map['built_in'] = Variable<bool>(builtIn.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('extensions: $extensions, ')
          ..write('saveDir: $saveDir, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('builtIn: $builtIn')
          ..write(')'))
        .toString();
  }
}

class $SiteRulesTable extends SiteRules
    with TableInfo<$SiteRulesTable, SiteRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SiteRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxConnectionsMeta = const VerificationMeta(
    'maxConnections',
  );
  @override
  late final GeneratedColumn<int> maxConnections = GeneratedColumn<int>(
    'max_connections',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _neverInterceptMeta = const VerificationMeta(
    'neverIntercept',
  );
  @override
  late final GeneratedColumn<bool> neverIntercept = GeneratedColumn<bool>(
    'never_intercept',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("never_intercept" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [host, maxConnections, neverIntercept];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'site_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<SiteRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('max_connections')) {
      context.handle(
        _maxConnectionsMeta,
        maxConnections.isAcceptableOrUnknown(
          data['max_connections']!,
          _maxConnectionsMeta,
        ),
      );
    }
    if (data.containsKey('never_intercept')) {
      context.handle(
        _neverInterceptMeta,
        neverIntercept.isAcceptableOrUnknown(
          data['never_intercept']!,
          _neverInterceptMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {host};
  @override
  SiteRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SiteRuleRow(
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      maxConnections: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_connections'],
      ),
      neverIntercept: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}never_intercept'],
      )!,
    );
  }

  @override
  $SiteRulesTable createAlias(String alias) {
    return $SiteRulesTable(attachedDatabase, alias);
  }
}

class SiteRuleRow extends DataClass implements Insertable<SiteRuleRow> {
  final String host;
  final int? maxConnections;
  final bool neverIntercept;
  const SiteRuleRow({
    required this.host,
    this.maxConnections,
    required this.neverIntercept,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['host'] = Variable<String>(host);
    if (!nullToAbsent || maxConnections != null) {
      map['max_connections'] = Variable<int>(maxConnections);
    }
    map['never_intercept'] = Variable<bool>(neverIntercept);
    return map;
  }

  SiteRulesCompanion toCompanion(bool nullToAbsent) {
    return SiteRulesCompanion(
      host: Value(host),
      maxConnections: maxConnections == null && nullToAbsent
          ? const Value.absent()
          : Value(maxConnections),
      neverIntercept: Value(neverIntercept),
    );
  }

  factory SiteRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SiteRuleRow(
      host: serializer.fromJson<String>(json['host']),
      maxConnections: serializer.fromJson<int?>(json['maxConnections']),
      neverIntercept: serializer.fromJson<bool>(json['neverIntercept']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'host': serializer.toJson<String>(host),
      'maxConnections': serializer.toJson<int?>(maxConnections),
      'neverIntercept': serializer.toJson<bool>(neverIntercept),
    };
  }

  SiteRuleRow copyWith({
    String? host,
    Value<int?> maxConnections = const Value.absent(),
    bool? neverIntercept,
  }) => SiteRuleRow(
    host: host ?? this.host,
    maxConnections: maxConnections.present
        ? maxConnections.value
        : this.maxConnections,
    neverIntercept: neverIntercept ?? this.neverIntercept,
  );
  SiteRuleRow copyWithCompanion(SiteRulesCompanion data) {
    return SiteRuleRow(
      host: data.host.present ? data.host.value : this.host,
      maxConnections: data.maxConnections.present
          ? data.maxConnections.value
          : this.maxConnections,
      neverIntercept: data.neverIntercept.present
          ? data.neverIntercept.value
          : this.neverIntercept,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SiteRuleRow(')
          ..write('host: $host, ')
          ..write('maxConnections: $maxConnections, ')
          ..write('neverIntercept: $neverIntercept')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(host, maxConnections, neverIntercept);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SiteRuleRow &&
          other.host == this.host &&
          other.maxConnections == this.maxConnections &&
          other.neverIntercept == this.neverIntercept);
}

class SiteRulesCompanion extends UpdateCompanion<SiteRuleRow> {
  final Value<String> host;
  final Value<int?> maxConnections;
  final Value<bool> neverIntercept;
  final Value<int> rowid;
  const SiteRulesCompanion({
    this.host = const Value.absent(),
    this.maxConnections = const Value.absent(),
    this.neverIntercept = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SiteRulesCompanion.insert({
    required String host,
    this.maxConnections = const Value.absent(),
    this.neverIntercept = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : host = Value(host);
  static Insertable<SiteRuleRow> custom({
    Expression<String>? host,
    Expression<int>? maxConnections,
    Expression<bool>? neverIntercept,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (host != null) 'host': host,
      if (maxConnections != null) 'max_connections': maxConnections,
      if (neverIntercept != null) 'never_intercept': neverIntercept,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SiteRulesCompanion copyWith({
    Value<String>? host,
    Value<int?>? maxConnections,
    Value<bool>? neverIntercept,
    Value<int>? rowid,
  }) {
    return SiteRulesCompanion(
      host: host ?? this.host,
      maxConnections: maxConnections ?? this.maxConnections,
      neverIntercept: neverIntercept ?? this.neverIntercept,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (maxConnections.present) {
      map['max_connections'] = Variable<int>(maxConnections.value);
    }
    if (neverIntercept.present) {
      map['never_intercept'] = Variable<bool>(neverIntercept.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SiteRulesCompanion(')
          ..write('host: $host, ')
          ..write('maxConnections: $maxConnections, ')
          ..write('neverIntercept: $neverIntercept, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SiteLoginsTable extends SiteLogins
    with TableInfo<$SiteLoginsTable, SiteLoginRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SiteLoginsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [host, username];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'site_logins';
  @override
  VerificationContext validateIntegrity(
    Insertable<SiteLoginRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {host};
  @override
  SiteLoginRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SiteLoginRow(
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
    );
  }

  @override
  $SiteLoginsTable createAlias(String alias) {
    return $SiteLoginsTable(attachedDatabase, alias);
  }
}

class SiteLoginRow extends DataClass implements Insertable<SiteLoginRow> {
  final String host;
  final String username;
  const SiteLoginRow({required this.host, required this.username});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['host'] = Variable<String>(host);
    map['username'] = Variable<String>(username);
    return map;
  }

  SiteLoginsCompanion toCompanion(bool nullToAbsent) {
    return SiteLoginsCompanion(host: Value(host), username: Value(username));
  }

  factory SiteLoginRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SiteLoginRow(
      host: serializer.fromJson<String>(json['host']),
      username: serializer.fromJson<String>(json['username']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'host': serializer.toJson<String>(host),
      'username': serializer.toJson<String>(username),
    };
  }

  SiteLoginRow copyWith({String? host, String? username}) => SiteLoginRow(
    host: host ?? this.host,
    username: username ?? this.username,
  );
  SiteLoginRow copyWithCompanion(SiteLoginsCompanion data) {
    return SiteLoginRow(
      host: data.host.present ? data.host.value : this.host,
      username: data.username.present ? data.username.value : this.username,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SiteLoginRow(')
          ..write('host: $host, ')
          ..write('username: $username')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(host, username);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SiteLoginRow &&
          other.host == this.host &&
          other.username == this.username);
}

class SiteLoginsCompanion extends UpdateCompanion<SiteLoginRow> {
  final Value<String> host;
  final Value<String> username;
  final Value<int> rowid;
  const SiteLoginsCompanion({
    this.host = const Value.absent(),
    this.username = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SiteLoginsCompanion.insert({
    required String host,
    required String username,
    this.rowid = const Value.absent(),
  }) : host = Value(host),
       username = Value(username);
  static Insertable<SiteLoginRow> custom({
    Expression<String>? host,
    Expression<String>? username,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (host != null) 'host': host,
      if (username != null) 'username': username,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SiteLoginsCompanion copyWith({
    Value<String>? host,
    Value<String>? username,
    Value<int>? rowid,
  }) {
    return SiteLoginsCompanion(
      host: host ?? this.host,
      username: username ?? this.username,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SiteLoginsCompanion(')
          ..write('host: $host, ')
          ..write('username: $username, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HaulDatabase extends GeneratedDatabase {
  _$HaulDatabase(QueryExecutor e) : super(e);
  $HaulDatabaseManager get managers => $HaulDatabaseManager(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $SegmentsTable segments = $SegmentsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $SiteRulesTable siteRules = $SiteRulesTable(this);
  late final $SiteLoginsTable siteLogins = $SiteLoginsTable(this);
  late final DownloadsDao downloadsDao = DownloadsDao(this as HaulDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    downloads,
    segments,
    settings,
    categories,
    siteRules,
    siteLogins,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'downloads',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('segments', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DownloadsTableCreateCompanionBuilder = DownloadsCompanion Function({
  required String id,
  required String url,
  Value<String?> finalUrl,
  Value<String?> fileName,
  required String saveDir,
  Value<int?> totalBytes,
  Value<int> downloadedBytes,
  required String status,
  Value<bool> supportsRanges,
  Value<bool> resumable,
  Value<String?> etag,
  Value<String?> lastModified,
  Value<String?> contentType,
  Value<String> requestHeaders,
  Value<int> maxConnections,
  Value<int?> categoryId,
  Value<String> source,
  Value<String?> errorCode,
  Value<String?> errorMessage,
  required DateTime createdAt,
  Value<DateTime?> completedAt,
  Value<int> rowid,
});
typedef $$DownloadsTableUpdateCompanionBuilder = DownloadsCompanion Function({
  Value<String> id,
  Value<String> url,
  Value<String?> finalUrl,
  Value<String?> fileName,
  Value<String> saveDir,
  Value<int?> totalBytes,
  Value<int> downloadedBytes,
  Value<String> status,
  Value<bool> supportsRanges,
  Value<bool> resumable,
  Value<String?> etag,
  Value<String?> lastModified,
  Value<String?> contentType,
  Value<String> requestHeaders,
  Value<int> maxConnections,
  Value<int?> categoryId,
  Value<String> source,
  Value<String?> errorCode,
  Value<String?> errorMessage,
  Value<DateTime> createdAt,
  Value<DateTime?> completedAt,
  Value<int> rowid,
});

final class $$DownloadsTableReferences
    extends BaseReferences<_$HaulDatabase, $DownloadsTable, DownloadRow> {
  $$DownloadsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SegmentsTable, List<SegmentRow>>
  _segmentsRefsTable(_$HaulDatabase db) => MultiTypedResultKey.fromTable(
    db.segments,
    aliasName: 'downloads__id__segments__download_id',
  );

  $$SegmentsTableProcessedTableManager get segmentsRefs {
    final manager = $$SegmentsTableTableManager(
      $_db,
      $_db.segments,
    ).filter((f) => f.downloadId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_segmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DownloadsTableFilterComposer
    extends Composer<_$HaulDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalUrl => $composableBuilder(
    column: $table.finalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saveDir => $composableBuilder(
    column: $table.saveDir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsRanges => $composableBuilder(
    column: $table.supportsRanges,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get resumable => $composableBuilder(
    column: $table.resumable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestHeaders => $composableBuilder(
    column: $table.requestHeaders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxConnections => $composableBuilder(
    column: $table.maxConnections,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> segmentsRefs(
    Expression<bool> Function($$SegmentsTableFilterComposer f) f,
  ) {
    final $$SegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.downloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentsTableFilterComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$HaulDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalUrl => $composableBuilder(
    column: $table.finalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saveDir => $composableBuilder(
    column: $table.saveDir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsRanges => $composableBuilder(
    column: $table.supportsRanges,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get resumable => $composableBuilder(
    column: $table.resumable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestHeaders => $composableBuilder(
    column: $table.requestHeaders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxConnections => $composableBuilder(
    column: $table.maxConnections,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$HaulDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get finalUrl =>
      $composableBuilder(column: $table.finalUrl, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get saveDir =>
      $composableBuilder(column: $table.saveDir, builder: (column) => column);

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get supportsRanges => $composableBuilder(
    column: $table.supportsRanges,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get resumable =>
      $composableBuilder(column: $table.resumable, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get requestHeaders => $composableBuilder(
    column: $table.requestHeaders,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxConnections => $composableBuilder(
    column: $table.maxConnections,
    builder: (column) => column,
  );

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  Expression<T> segmentsRefs<T extends Object>(
    Expression<T> Function($$SegmentsTableAnnotationComposer a) f,
  ) {
    final $$SegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.downloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$HaulDatabase,
          $DownloadsTable,
          DownloadRow,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (DownloadRow, $$DownloadsTableReferences),
          DownloadRow,
          PrefetchHooks Function({bool segmentsRefs})
        > {
  $$DownloadsTableTableManager(_$HaulDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> finalUrl = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<String> saveDir = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> supportsRanges = const Value.absent(),
                Value<bool> resumable = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<String> requestHeaders = const Value.absent(),
                Value<int> maxConnections = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion(
                id: id,
                url: url,
                finalUrl: finalUrl,
                fileName: fileName,
                saveDir: saveDir,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                status: status,
                supportsRanges: supportsRanges,
                resumable: resumable,
                etag: etag,
                lastModified: lastModified,
                contentType: contentType,
                requestHeaders: requestHeaders,
                maxConnections: maxConnections,
                categoryId: categoryId,
                source: source,
                errorCode: errorCode,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String url,
                Value<String?> finalUrl = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                required String saveDir,
                Value<int?> totalBytes = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                required String status,
                Value<bool> supportsRanges = const Value.absent(),
                Value<bool> resumable = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<String> requestHeaders = const Value.absent(),
                Value<int> maxConnections = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion.insert(
                id: id,
                url: url,
                finalUrl: finalUrl,
                fileName: fileName,
                saveDir: saveDir,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                status: status,
                supportsRanges: supportsRanges,
                resumable: resumable,
                etag: etag,
                lastModified: lastModified,
                contentType: contentType,
                requestHeaders: requestHeaders,
                maxConnections: maxConnections,
                categoryId: categoryId,
                source: source,
                errorCode: errorCode,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadsTable, DownloadRow>(table),
                  $$DownloadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({segmentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (segmentsRefs) db.segments],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (segmentsRefs)
                    await $_getPrefetchedDataByColumns<
                      DownloadRow,
                      $DownloadsTable,
                      SegmentRow,
                      $SegmentsTable
                    >(
                      currentTable: table,
                      referencedTable: $$DownloadsTableReferences
                          ._segmentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DownloadsTableReferences(
                            db,
                            table,
                            p0,
                          ).segmentsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'download_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$HaulDatabase,
      $DownloadsTable,
      DownloadRow,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (DownloadRow, $$DownloadsTableReferences),
      DownloadRow,
      PrefetchHooks Function({bool segmentsRefs})
    >;
typedef $$SegmentsTableCreateCompanionBuilder = SegmentsCompanion Function({
  Value<int> id,
  required String downloadId,
  required int segmentIndex,
  required int startOffset,
  required int endOffset,
  Value<int> downloadedBytes,
  required String status,
});
typedef $$SegmentsTableUpdateCompanionBuilder = SegmentsCompanion Function({
  Value<int> id,
  Value<String> downloadId,
  Value<int> segmentIndex,
  Value<int> startOffset,
  Value<int> endOffset,
  Value<int> downloadedBytes,
  Value<String> status,
});

final class $$SegmentsTableReferences
    extends BaseReferences<_$HaulDatabase, $SegmentsTable, SegmentRow> {
  $$SegmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DownloadsTable _downloadIdTable(_$HaulDatabase db) =>
      db.downloads.createAlias('segments__download_id__downloads__id');

  $$DownloadsTableProcessedTableManager get downloadId {
    final $_column = $_itemColumn<String>('download_id')!;

    final manager = $$DownloadsTableTableManager(
      $_db,
      $_db.downloads,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_downloadIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SegmentsTableFilterComposer
    extends Composer<_$HaulDatabase, $SegmentsTable> {
  $$SegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$DownloadsTableFilterComposer get downloadId {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.downloadId,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableFilterComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentsTableOrderingComposer
    extends Composer<_$HaulDatabase, $SegmentsTable> {
  $$SegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$DownloadsTableOrderingComposer get downloadId {
    final $$DownloadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.downloadId,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableOrderingComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentsTableAnnotationComposer
    extends Composer<_$HaulDatabase, $SegmentsTable> {
  $$SegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$DownloadsTableAnnotationComposer get downloadId {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.downloadId,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentsTableTableManager
    extends
        RootTableManager<
          _$HaulDatabase,
          $SegmentsTable,
          SegmentRow,
          $$SegmentsTableFilterComposer,
          $$SegmentsTableOrderingComposer,
          $$SegmentsTableAnnotationComposer,
          $$SegmentsTableCreateCompanionBuilder,
          $$SegmentsTableUpdateCompanionBuilder,
          (SegmentRow, $$SegmentsTableReferences),
          SegmentRow,
          PrefetchHooks Function({bool downloadId})
        > {
  $$SegmentsTableTableManager(_$HaulDatabase db, $SegmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> downloadId = const Value.absent(),
                Value<int> segmentIndex = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => SegmentsCompanion(
                id: id,
                downloadId: downloadId,
                segmentIndex: segmentIndex,
                startOffset: startOffset,
                endOffset: endOffset,
                downloadedBytes: downloadedBytes,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String downloadId,
                required int segmentIndex,
                required int startOffset,
                required int endOffset,
                Value<int> downloadedBytes = const Value.absent(),
                required String status,
              }) => SegmentsCompanion.insert(
                id: id,
                downloadId: downloadId,
                segmentIndex: segmentIndex,
                startOffset: startOffset,
                endOffset: endOffset,
                downloadedBytes: downloadedBytes,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SegmentsTable, SegmentRow>(table),
                  $$SegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({downloadId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (downloadId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.downloadId,
                        referencedTable: $$SegmentsTableReferences
                            ._downloadIdTable(db),
                        referencedColumn: $$SegmentsTableReferences
                            ._downloadIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$HaulDatabase,
      $SegmentsTable,
      SegmentRow,
      $$SegmentsTableFilterComposer,
      $$SegmentsTableOrderingComposer,
      $$SegmentsTableAnnotationComposer,
      $$SegmentsTableCreateCompanionBuilder,
      $$SegmentsTableUpdateCompanionBuilder,
      (SegmentRow, $$SegmentsTableReferences),
      SegmentRow,
      PrefetchHooks Function({bool downloadId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$HaulDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$HaulDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$HaulDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$HaulDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$HaulDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$HaulDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$HaulDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$HaulDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$HaulDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  required String name,
  Value<String> extensions,
  required String saveDir,
  Value<int> sortOrder,
  Value<bool> builtIn,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> extensions,
  Value<String> saveDir,
  Value<int> sortOrder,
  Value<bool> builtIn,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$HaulDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extensions => $composableBuilder(
    column: $table.extensions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saveDir => $composableBuilder(
    column: $table.saveDir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get builtIn => $composableBuilder(
    column: $table.builtIn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$HaulDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extensions => $composableBuilder(
    column: $table.extensions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saveDir => $composableBuilder(
    column: $table.saveDir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get builtIn => $composableBuilder(
    column: $table.builtIn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$HaulDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get extensions => $composableBuilder(
    column: $table.extensions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get saveDir =>
      $composableBuilder(column: $table.saveDir, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get builtIn =>
      $composableBuilder(column: $table.builtIn, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$HaulDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (
            CategoryRow,
            BaseReferences<_$HaulDatabase, $CategoriesTable, CategoryRow>,
          ),
          CategoryRow,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$HaulDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> extensions = const Value.absent(),
                Value<String> saveDir = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> builtIn = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                extensions: extensions,
                saveDir: saveDir,
                sortOrder: sortOrder,
                builtIn: builtIn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> extensions = const Value.absent(),
                required String saveDir,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> builtIn = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                extensions: extensions,
                saveDir: saveDir,
                sortOrder: sortOrder,
                builtIn: builtIn,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, CategoryRow>(table),
                  BaseReferences<_$HaulDatabase, $CategoriesTable, CategoryRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$HaulDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (
        CategoryRow,
        BaseReferences<_$HaulDatabase, $CategoriesTable, CategoryRow>,
      ),
      CategoryRow,
      PrefetchHooks Function()
    >;
typedef $$SiteRulesTableCreateCompanionBuilder = SiteRulesCompanion Function({
  required String host,
  Value<int?> maxConnections,
  Value<bool> neverIntercept,
  Value<int> rowid,
});
typedef $$SiteRulesTableUpdateCompanionBuilder = SiteRulesCompanion Function({
  Value<String> host,
  Value<int?> maxConnections,
  Value<bool> neverIntercept,
  Value<int> rowid,
});

class $$SiteRulesTableFilterComposer
    extends Composer<_$HaulDatabase, $SiteRulesTable> {
  $$SiteRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxConnections => $composableBuilder(
    column: $table.maxConnections,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get neverIntercept => $composableBuilder(
    column: $table.neverIntercept,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SiteRulesTableOrderingComposer
    extends Composer<_$HaulDatabase, $SiteRulesTable> {
  $$SiteRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxConnections => $composableBuilder(
    column: $table.maxConnections,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get neverIntercept => $composableBuilder(
    column: $table.neverIntercept,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SiteRulesTableAnnotationComposer
    extends Composer<_$HaulDatabase, $SiteRulesTable> {
  $$SiteRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get maxConnections => $composableBuilder(
    column: $table.maxConnections,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get neverIntercept => $composableBuilder(
    column: $table.neverIntercept,
    builder: (column) => column,
  );
}

class $$SiteRulesTableTableManager
    extends
        RootTableManager<
          _$HaulDatabase,
          $SiteRulesTable,
          SiteRuleRow,
          $$SiteRulesTableFilterComposer,
          $$SiteRulesTableOrderingComposer,
          $$SiteRulesTableAnnotationComposer,
          $$SiteRulesTableCreateCompanionBuilder,
          $$SiteRulesTableUpdateCompanionBuilder,
          (
            SiteRuleRow,
            BaseReferences<_$HaulDatabase, $SiteRulesTable, SiteRuleRow>,
          ),
          SiteRuleRow,
          PrefetchHooks Function()
        > {
  $$SiteRulesTableTableManager(_$HaulDatabase db, $SiteRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SiteRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SiteRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SiteRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> host = const Value.absent(),
                Value<int?> maxConnections = const Value.absent(),
                Value<bool> neverIntercept = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SiteRulesCompanion(
                host: host,
                maxConnections: maxConnections,
                neverIntercept: neverIntercept,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String host,
                Value<int?> maxConnections = const Value.absent(),
                Value<bool> neverIntercept = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SiteRulesCompanion.insert(
                host: host,
                maxConnections: maxConnections,
                neverIntercept: neverIntercept,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SiteRulesTable, SiteRuleRow>(table),
                  BaseReferences<_$HaulDatabase, $SiteRulesTable, SiteRuleRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SiteRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$HaulDatabase,
      $SiteRulesTable,
      SiteRuleRow,
      $$SiteRulesTableFilterComposer,
      $$SiteRulesTableOrderingComposer,
      $$SiteRulesTableAnnotationComposer,
      $$SiteRulesTableCreateCompanionBuilder,
      $$SiteRulesTableUpdateCompanionBuilder,
      (
        SiteRuleRow,
        BaseReferences<_$HaulDatabase, $SiteRulesTable, SiteRuleRow>,
      ),
      SiteRuleRow,
      PrefetchHooks Function()
    >;
typedef $$SiteLoginsTableCreateCompanionBuilder = SiteLoginsCompanion Function({
  required String host,
  required String username,
  Value<int> rowid,
});
typedef $$SiteLoginsTableUpdateCompanionBuilder = SiteLoginsCompanion Function({
  Value<String> host,
  Value<String> username,
  Value<int> rowid,
});

class $$SiteLoginsTableFilterComposer
    extends Composer<_$HaulDatabase, $SiteLoginsTable> {
  $$SiteLoginsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SiteLoginsTableOrderingComposer
    extends Composer<_$HaulDatabase, $SiteLoginsTable> {
  $$SiteLoginsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SiteLoginsTableAnnotationComposer
    extends Composer<_$HaulDatabase, $SiteLoginsTable> {
  $$SiteLoginsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);
}

class $$SiteLoginsTableTableManager
    extends
        RootTableManager<
          _$HaulDatabase,
          $SiteLoginsTable,
          SiteLoginRow,
          $$SiteLoginsTableFilterComposer,
          $$SiteLoginsTableOrderingComposer,
          $$SiteLoginsTableAnnotationComposer,
          $$SiteLoginsTableCreateCompanionBuilder,
          $$SiteLoginsTableUpdateCompanionBuilder,
          (
            SiteLoginRow,
            BaseReferences<_$HaulDatabase, $SiteLoginsTable, SiteLoginRow>,
          ),
          SiteLoginRow,
          PrefetchHooks Function()
        > {
  $$SiteLoginsTableTableManager(_$HaulDatabase db, $SiteLoginsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SiteLoginsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SiteLoginsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SiteLoginsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> host = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SiteLoginsCompanion(
                host: host,
                username: username,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String host,
                required String username,
                Value<int> rowid = const Value.absent(),
              }) => SiteLoginsCompanion.insert(
                host: host,
                username: username,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SiteLoginsTable, SiteLoginRow>(table),
                  BaseReferences<
                    _$HaulDatabase,
                    $SiteLoginsTable,
                    SiteLoginRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SiteLoginsTableProcessedTableManager =
    ProcessedTableManager<
      _$HaulDatabase,
      $SiteLoginsTable,
      SiteLoginRow,
      $$SiteLoginsTableFilterComposer,
      $$SiteLoginsTableOrderingComposer,
      $$SiteLoginsTableAnnotationComposer,
      $$SiteLoginsTableCreateCompanionBuilder,
      $$SiteLoginsTableUpdateCompanionBuilder,
      (
        SiteLoginRow,
        BaseReferences<_$HaulDatabase, $SiteLoginsTable, SiteLoginRow>,
      ),
      SiteLoginRow,
      PrefetchHooks Function()
    >;

class $HaulDatabaseManager {
  final _$HaulDatabase _db;
  $HaulDatabaseManager(this._db);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$SegmentsTableTableManager get segments =>
      $$SegmentsTableTableManager(_db, _db.segments);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$SiteRulesTableTableManager get siteRules =>
      $$SiteRulesTableTableManager(_db, _db.siteRules);
  $$SiteLoginsTableTableManager get siteLogins =>
      $$SiteLoginsTableTableManager(_db, _db.siteLogins);
}
