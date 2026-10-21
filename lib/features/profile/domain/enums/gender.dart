/// Gender identity options
enum Gender {
  male,
  female,
  nonBinary,
  other;

  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.nonBinary:
        // Must match the backend's Gender.displayName exactly, because it is also the wire
        // value. 'Non-binary' was rejected by POST /users.
        return 'Non-Binary';
      case Gender.other:
        return 'Other';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static Gender fromBackend(String value) {
    return Gender.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid Gender value: $value. Expected one of: ${Gender.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }

  /// Parses a value the app saved itself, such as an onboarding draft. Builds before the
  /// 'Non-Binary' fix saved 'Non-binary', and a draft that fails to parse is thrown away, so
  /// the old spelling is still accepted here. [fromBackend] stays exact for server values.
  static Gender fromStored(String value) =>
      value == 'Non-binary' ? Gender.nonBinary : fromBackend(value);
}
