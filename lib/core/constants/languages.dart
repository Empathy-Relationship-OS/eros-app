/// Supported app languages enum
enum LanguageCode {
  english,
  spanish,
  french,
  german,
  italian,
  portuguese,
  dutch,
  polish,
  russian,
  japanese,
  chinese,
  korean;

  String get displayName {
    switch (this) {
      case LanguageCode.english:
        return 'English';
      case LanguageCode.spanish:
        return 'Spanish';
      case LanguageCode.french:
        return 'French';
      case LanguageCode.german:
        return 'German';
      case LanguageCode.italian:
        return 'Italian';
      case LanguageCode.portuguese:
        return 'Portuguese';
      case LanguageCode.dutch:
        return 'Dutch';
      case LanguageCode.polish:
        return 'Polish';
      case LanguageCode.russian:
        return 'Russian';
      case LanguageCode.japanese:
        return 'Japanese';
      case LanguageCode.chinese:
        return 'Chinese';
      case LanguageCode.korean:
        return 'Korean';
    }
  }

  String get nativeName {
    switch (this) {
      case LanguageCode.english:
        return 'English';
      case LanguageCode.spanish:
        return 'Español';
      case LanguageCode.french:
        return 'Français';
      case LanguageCode.german:
        return 'Deutsch';
      case LanguageCode.italian:
        return 'Italiano';
      case LanguageCode.portuguese:
        return 'Português';
      case LanguageCode.dutch:
        return 'Nederlands';
      case LanguageCode.polish:
        return 'Polski';
      case LanguageCode.russian:
        return 'Русский';
      case LanguageCode.japanese:
        return '日本語';
      case LanguageCode.chinese:
        return '中文';
      case LanguageCode.korean:
        return '한국어';
    }
  }

  String get flag {
    switch (this) {
      case LanguageCode.english:
        return '🇬🇧';
      case LanguageCode.spanish:
        return '🇪🇸';
      case LanguageCode.french:
        return '🇫🇷';
      case LanguageCode.german:
        return '🇩🇪';
      case LanguageCode.italian:
        return '🇮🇹';
      case LanguageCode.portuguese:
        return '🇵🇹';
      case LanguageCode.dutch:
        return '🇳🇱';
      case LanguageCode.polish:
        return '🇵🇱';
      case LanguageCode.russian:
        return '🇷🇺';
      case LanguageCode.japanese:
        return '🇯🇵';
      case LanguageCode.chinese:
        return '🇨🇳';
      case LanguageCode.korean:
        return '🇰🇷';
    }
  }

  String get code {
    switch (this) {
      case LanguageCode.english:
        return 'en';
      case LanguageCode.spanish:
        return 'es';
      case LanguageCode.french:
        return 'fr';
      case LanguageCode.german:
        return 'de';
      case LanguageCode.italian:
        return 'it';
      case LanguageCode.portuguese:
        return 'pt';
      case LanguageCode.dutch:
        return 'nl';
      case LanguageCode.polish:
        return 'pl';
      case LanguageCode.russian:
        return 'ru';
      case LanguageCode.japanese:
        return 'ja';
      case LanguageCode.chinese:
        return 'zh';
      case LanguageCode.korean:
        return 'ko';
    }
  }

  String toBackend() {
    switch (this) {
      case LanguageCode.english:
        return 'ENGLISH';
      case LanguageCode.spanish:
        return 'SPANISH';
      case LanguageCode.french:
        return 'FRENCH';
      case LanguageCode.german:
        return 'GERMAN';
      case LanguageCode.italian:
        return 'ITALIAN';
      case LanguageCode.portuguese:
        return 'PORTUGUESE';
      case LanguageCode.dutch:
        return 'DUTCH';
      case LanguageCode.polish:
        return 'POLISH';
      case LanguageCode.russian:
        return 'RUSSIAN';
      case LanguageCode.japanese:
        return 'JAPANESE';
      case LanguageCode.chinese:
        return 'CHINESE';
      case LanguageCode.korean:
        return 'KOREAN';
    }
  }

  static LanguageCode fromBackend(String value) {
    switch (value) {
      case 'ENGLISH':
        return LanguageCode.english;
      case 'SPANISH':
        return LanguageCode.spanish;
      case 'FRENCH':
        return LanguageCode.french;
      case 'GERMAN':
        return LanguageCode.german;
      case 'ITALIAN':
        return LanguageCode.italian;
      case 'PORTUGUESE':
        return LanguageCode.portuguese;
      case 'DUTCH':
        return LanguageCode.dutch;
      case 'POLISH':
        return LanguageCode.polish;
      case 'RUSSIAN':
        return LanguageCode.russian;
      case 'JAPANESE':
        return LanguageCode.japanese;
      case 'CHINESE':
        return LanguageCode.chinese;
      case 'KOREAN':
        return LanguageCode.korean;
      default:
        throw ArgumentError('Invalid LanguageCode value: $value');
    }
  }

  static LanguageCode fromCode(String code) {
    switch (code) {
      case 'en':
        return LanguageCode.english;
      case 'es':
        return LanguageCode.spanish;
      case 'fr':
        return LanguageCode.french;
      case 'de':
        return LanguageCode.german;
      case 'it':
        return LanguageCode.italian;
      case 'pt':
        return LanguageCode.portuguese;
      case 'nl':
        return LanguageCode.dutch;
      case 'pl':
        return LanguageCode.polish;
      case 'ru':
        return LanguageCode.russian;
      case 'ja':
        return LanguageCode.japanese;
      case 'zh':
        return LanguageCode.chinese;
      case 'ko':
        return LanguageCode.korean;
      default:
        return LanguageCode.english; // Default to English
    }
  }
}

/// Supported app languages
/// These values should be cached locally for user preference
class Language {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });

  /// Create Language from code
  factory Language.fromCode(String code) {
    return Languages.all.firstWhere(
      (lang) => lang.code == code,
      orElse: () => Languages.all.first,
    );
  }

  /// Create Language from enum
  factory Language.fromEnum(LanguageCode languageCode) {
    return Language(
      code: languageCode.code,
      name: languageCode.displayName,
      nativeName: languageCode.nativeName,
      flag: languageCode.flag,
    );
  }

  /// Convert to enum
  LanguageCode toEnum() {
    return LanguageCode.fromCode(code);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Language &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Legacy alias for backward compatibility
typedef AppLanguage = Language;

/// List of all available app languages
/// Reference: screenshots/login/create-user/84623CD3-B81C-46DF-84FD-5F2C81BC72D9_1_105_c.jpeg
class Languages {
  Languages._();

  static const List<Language> all = [
    Language(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇬🇧',
    ),
    Language(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
    Language(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
    ),
    Language(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
    ),
    Language(
      code: 'it',
      name: 'Italian',
      nativeName: 'Italiano',
      flag: '🇮🇹',
    ),
    Language(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      flag: '🇵🇹',
    ),
    Language(
      code: 'nl',
      name: 'Dutch',
      nativeName: 'Nederlands',
      flag: '🇳🇱',
    ),
    Language(
      code: 'pl',
      name: 'Polish',
      nativeName: 'Polski',
      flag: '🇵🇱',
    ),
    Language(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
      flag: '🇷🇺',
    ),
    Language(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      flag: '🇯🇵',
    ),
    Language(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
    ),
    Language(
      code: 'ko',
      name: 'Korean',
      nativeName: '한국어',
      flag: '🇰🇷',
    ),
  ];

  static Language getByCode(String code) {
    return all.firstWhere(
      (lang) => lang.code == code,
      orElse: () => all.first, // Default to English
    );
  }
}

/// Legacy alias for backward compatibility
typedef AppLanguages = Languages;
