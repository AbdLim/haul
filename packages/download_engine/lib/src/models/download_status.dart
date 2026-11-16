enum DownloadStatus {
  queued,
  probing,
  downloading,
  paused,
  completed,
  failed,
  needsRefresh;

  bool get isActive => this == probing || this == downloading;
  bool get isFinished => this == completed;

  /// Statuses a user can restart from.
  bool get canResume =>
      this == paused || this == failed || this == needsRefresh;
}
