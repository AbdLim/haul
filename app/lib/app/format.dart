String formatBytes(num bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  final digits = i == 0 || value >= 100 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(digits)} ${units[i]}';
}

String formatSpeed(double bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';

/// Time left as `1h 02m` or, under an hour, `3m 05s` or `45s`. The smaller
/// unit is zero-padded so the width barely changes as it counts down.
String formatEta(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  if (d.inHours >= 1) return '${d.inHours}h ${two(d.inMinutes % 60)}m';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ${two(d.inSeconds % 60)}s';
  return '${d.inSeconds}s';
}
