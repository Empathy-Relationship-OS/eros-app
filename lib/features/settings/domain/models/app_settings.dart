import 'package:eros_app/core/constants/languages.dart';

/// App settings model
class AppSettings {
  final bool notificationsEnabled;
  final Language language;

  const AppSettings({
    required this.notificationsEnabled,
    required this.language,
  });

  /// Default settings
  factory AppSettings.defaultSettings() {
    return AppSettings(
      notificationsEnabled: false,
      language: Languages.all.first, // English
    );
  }

  /// Create from JSON (for SharedPreferences)
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      language: Language.fromCode(json['languageCode'] as String? ?? 'en'),
    );
  }

  /// Convert to JSON (for SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'languageCode': language.code,
    };
  }

  /// Copy with
  AppSettings copyWith({
    bool? notificationsEnabled,
    Language? language,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          notificationsEnabled == other.notificationsEnabled &&
          language == other.language;

  @override
  int get hashCode => Object.hash(notificationsEnabled, language);
}
