import 'dart:convert';

/// A typed handle for one row of the settings table.
///
/// The value is stored as JSON text. Anything that fails to decode, such as
/// a corrupted row or a value from a future version, reads as [defaultValue]
/// instead of throwing.
class SettingKey<T> {
  const SettingKey(
    this.name,
    this.defaultValue, {
    required this.decode,
    required this.encode,
  });

  final String name;
  final T defaultValue;
  final T Function(Object? json) decode;
  final Object? Function(T value) encode;

  T fromStored(String? stored) {
    if (stored == null) return defaultValue;
    try {
      return decode(jsonDecode(stored));
    } on Object {
      return defaultValue;
    }
  }

  String toStored(T value) => jsonEncode(encode(value));

  // -- common shapes -------------------------------------------------------

  static SettingKey<int> integer(String name, int defaultValue) =>
      SettingKey<int>(
        name,
        defaultValue,
        decode: (j) => (j! as num).toInt(),
        encode: (v) => v,
      );

  static SettingKey<bool> boolean(String name, bool defaultValue) =>
      SettingKey<bool>(
        name,
        defaultValue,
        decode: (j) => j! as bool,
        encode: (v) => v,
      );

  static SettingKey<String> string(String name, String defaultValue) =>
      SettingKey<String>(
        name,
        defaultValue,
        decode: (j) => j! as String,
        encode: (v) => v,
      );

  static SettingKey<String?> optionalString(String name) => SettingKey<String?>(
    name,
    null,
    decode: (j) => j as String?,
    encode: (v) => v,
  );

  static SettingKey<int?> optionalInt(String name) => SettingKey<int?>(
    name,
    null,
    decode: (j) => (j as num?)?.toInt(),
    encode: (v) => v,
  );

  static SettingKey<List<String>> stringList(
    String name,
    List<String> defaultValue,
  ) => SettingKey<List<String>>(
    name,
    defaultValue,
    decode: (j) => (j! as List<Object?>).cast<String>(),
    encode: (v) => v,
  );

  static SettingKey<E> enumeration<E extends Enum>(
    String name,
    List<E> values,
    E defaultValue,
  ) => SettingKey<E>(
    name,
    defaultValue,
    decode: (j) => values.byName(j! as String),
    encode: (v) => v.name,
  );
}
